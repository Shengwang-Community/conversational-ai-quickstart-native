package cn.shengwang.convoai.quickstart.ui;

import android.graphics.drawable.GradientDrawable;
import android.text.SpannableStringBuilder;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ScrollView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.DiffUtil;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.ListAdapter;
import androidx.recyclerview.widget.RecyclerView;

import java.util.ArrayList;
import java.util.Locale;

import cn.shengwang.convoai.quickstart.R;
import cn.shengwang.convoai.quickstart.databinding.ActivityAgentChatBinding;
import cn.shengwang.convoai.quickstart.databinding.ItemTranscriptAgentBinding;
import cn.shengwang.convoai.quickstart.databinding.ItemTranscriptUserBinding;
import cn.shengwang.convoai.quickstart.tools.PermissionHelp;
import cn.shengwang.convoai.quickstart.ui.common.BaseActivity;
import io.agora.convoai.convoaiApi.AgentState;
import io.agora.convoai.convoaiApi.Transcript;
import io.agora.convoai.convoaiApi.TranscriptType;

/**
 * Activity for agent chat interface.
 */
public class AgentChatActivity extends BaseActivity<ActivityAgentChatBinding> {

    private AgentChatViewModel viewModel;
    private PermissionHelp permissionHelp;
    private TranscriptAdapter transcriptAdapter;

    private boolean autoScrollToBottom = true;
    private boolean isScrollBottom = false;

    @Override
    protected ActivityAgentChatBinding getViewBinding() {
        return ActivityAgentChatBinding.inflate(getLayoutInflater());
    }

    @Override
    public void initData() {
        super.initData();
        viewModel = new ViewModelProvider(this).get(AgentChatViewModel.class);
        permissionHelp = new PermissionHelp(this);
        transcriptAdapter = new TranscriptAdapter();

        observeUiState();
        observeTranscriptList();
        observeDebugLogs();
    }

    @Override
    protected void initView() {
        ActivityAgentChatBinding binding = getBinding();
        if (binding == null) {
            return;
        }

        setOnApplyWindowInsetsListener(binding.getRoot());
        setupRecyclerView();

        binding.btnStart.setOnClickListener(v -> {
            String channelName = AgentChatViewModel.generateRandomChannelName();
            checkMicrophonePermission(granted -> {
                if (granted) {
                    viewModel.joinChannelAndLogin(channelName);
                } else {
                    Toast.makeText(
                        AgentChatActivity.this,
                        "Microphone permission is required to join channel",
                        Toast.LENGTH_LONG
                    ).show();
                }
            });
        });

        binding.btnMute.setOnClickListener(v -> viewModel.toggleMute());
        binding.btnStop.setOnClickListener(v -> viewModel.hangup());
    }

    private void checkMicrophonePermission(PermissionCallback callback) {
        if (permissionHelp.hasMicPerm()) {
            callback.onResult(true);
        } else {
            permissionHelp.checkMicPerm(
                () -> callback.onResult(true),
                () -> showPermissionDialog(
                    "Permission Required",
                    "Microphone permission is required for voice chat. Please grant the permission to continue.",
                    result -> {
                        if (result) {
                            permissionHelp.launchAppSettingForMic(
                                () -> callback.onResult(true),
                                () -> callback.onResult(false)
                            );
                        } else {
                            callback.onResult(false);
                        }
                    }
                )
            );
        }
    }

    private void showPermissionDialog(String title, String content, PermissionCallback onResult) {
        if (isFinishing() || isDestroyed() || getSupportFragmentManager().isStateSaved()) {
            return;
        }

        new CommonDialog.Builder()
            .setTitle(title)
            .setContent(content)
            .setPositiveButton("Retry", () -> onResult.onResult(true))
            .setNegativeButton("Exit", () -> onResult.onResult(false))
            .setCancelable(false)
            .build()
            .show(getSupportFragmentManager(), "permission_dialog");
    }

    private interface PermissionCallback {
        void onResult(boolean granted);
    }

    private void setupRecyclerView() {
        ActivityAgentChatBinding binding = getBinding();
        if (binding == null) {
            return;
        }

        RecyclerView recyclerView = binding.rvTranscript;
        LinearLayoutManager linearLayoutManager = new LinearLayoutManager(this);
        linearLayoutManager.setReverseLayout(false);
        recyclerView.setLayoutManager(linearLayoutManager);
        recyclerView.setAdapter(transcriptAdapter);
        recyclerView.setItemAnimator(null);
        recyclerView.addOnScrollListener(new RecyclerView.OnScrollListener() {
            @Override
            public void onScrollStateChanged(@NonNull RecyclerView recyclerView, int newState) {
                super.onScrollStateChanged(recyclerView, newState);
                switch (newState) {
                    case RecyclerView.SCROLL_STATE_IDLE:
                        isScrollBottom = !recyclerView.canScrollVertically(1);
                        if (isScrollBottom) {
                            autoScrollToBottom = true;
                            isScrollBottom = true;
                        }
                        break;
                    case RecyclerView.SCROLL_STATE_DRAGGING:
                        autoScrollToBottom = false;
                        break;
                    default:
                        break;
                }
            }

            @Override
            public void onScrolled(@NonNull RecyclerView recyclerView, int dx, int dy) {
                super.onScrolled(recyclerView, dx, dy);
                if (dy < -50 && recyclerView.canScrollVertically(1)) {
                    autoScrollToBottom = false;
                }
            }
        });
    }

    private void observeUiState() {
        viewModel.uiState.observe(this, state -> {
            ActivityAgentChatBinding binding = getBinding();
            if (binding == null || state == null) {
                return;
            }

            boolean isConnected = state.connectionState == AgentChatViewModel.ConnectionState.Connected;
            boolean isConnecting = state.connectionState == AgentChatViewModel.ConnectionState.Connecting;
            boolean isError = state.connectionState == AgentChatViewModel.ConnectionState.Error;

            binding.llStart.setVisibility(isConnected ? View.GONE : View.VISIBLE);
            binding.llControls.setVisibility(isConnected ? View.VISIBLE : View.GONE);

            if (isConnecting) {
                binding.btnStart.setText("Connecting...");
                binding.btnStart.setEnabled(false);
                binding.btnStart.setBackgroundResource(R.drawable.bg_start_button_disabled);
                binding.btnStart.setTextColor(ContextCompat.getColor(this, R.color.btn_disabled_text));
            } else if (isError) {
                binding.btnStart.setText("Retry");
                binding.btnStart.setEnabled(true);
                binding.btnStart.setBackgroundResource(R.drawable.bg_start_button_error);
                binding.btnStart.setTextColor(ContextCompat.getColor(this, R.color.white));
            } else {
                binding.btnStart.setText("Start Agent");
                binding.btnStart.setEnabled(true);
                binding.btnStart.setBackgroundResource(R.drawable.selector_gradient_button);
                binding.btnStart.setTextColor(ContextCompat.getColor(this, R.color.white));
            }

            if (state.isMuted) {
                binding.btnMute.setImageResource(R.drawable.ic_mic_off);
                binding.btnMute.setBackgroundResource(R.drawable.bg_button_mute_muted);
                binding.btnMute.setColorFilter(ContextCompat.getColor(this, R.color.mic_muted_icon));
            } else {
                binding.btnMute.setImageResource(R.drawable.ic_mic);
                binding.btnMute.setBackgroundResource(R.drawable.bg_button_mute_selector);
                binding.btnMute.setColorFilter(ContextCompat.getColor(this, R.color.mic_normal_icon));
            }
        });

        viewModel.agentState.observe(this, agentState -> {
            ActivityAgentChatBinding binding = getBinding();
            if (binding == null) {
                return;
            }

            AgentState state = agentState != null ? agentState : AgentState.IDLE;
            binding.tvAgentStatus.setText(capitalizeStateLabel(state.getValue()));

            int stateColorRes;
            switch (state) {
                case LISTENING:
                    stateColorRes = R.color.state_listening;
                    break;
                case THINKING:
                    stateColorRes = R.color.state_thinking;
                    break;
                case SPEAKING:
                    stateColorRes = R.color.state_speaking;
                    break;
                case SILENT:
                    stateColorRes = R.color.state_silent;
                    break;
                case UNKNOWN:
                    stateColorRes = R.color.text_tertiary;
                    break;
                case IDLE:
                default:
                    stateColorRes = R.color.state_idle;
                    break;
            }

            int stateColor = ContextCompat.getColor(this, stateColorRes);
            binding.tvAgentStatus.setTextColor(stateColor);

            if (binding.viewStatusDot.getBackground() instanceof GradientDrawable) {
                ((GradientDrawable) binding.viewStatusDot.getBackground()).setColor(stateColor);
            }
        });
    }

    private void observeTranscriptList() {
        viewModel.transcriptList.observe(this, transcriptList -> {
            transcriptAdapter.submitList(transcriptList != null ? transcriptList : new ArrayList<>());
            if (autoScrollToBottom) {
                scrollToBottom();
            }
        });
    }

    private void observeDebugLogs() {
        viewModel.debugLogList.observe(this, logList -> {
            ActivityAgentChatBinding binding = getBinding();
            if (binding == null) {
                return;
            }

            if (logList == null || logList.isEmpty()) {
                binding.tvLog.setText("log");
                return;
            }

            SpannableStringBuilder spannable = new SpannableStringBuilder();
            for (int index = 0; index < logList.size(); index++) {
                String log = logList.get(index);
                int start = spannable.length();
                spannable.append(log);
                int end = spannable.length();

                int colorRes;
                String lowerCaseLog = log.toLowerCase(Locale.US);
                if (lowerCaseLog.contains("failed") || lowerCaseLog.contains("error")) {
                    colorRes = R.color.error_red_light;
                } else if (lowerCaseLog.contains("successfully") || lowerCaseLog.contains("success")) {
                    colorRes = R.color.success_green_light;
                } else if (lowerCaseLog.contains("connecting") || lowerCaseLog.contains("starting")) {
                    colorRes = R.color.warning_amber_light;
                } else {
                    colorRes = R.color.text_secondary;
                }

                spannable.setSpan(
                    new ForegroundColorSpan(ContextCompat.getColor(this, colorRes)),
                    start,
                    end,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                );

                if (index < logList.size() - 1) {
                    spannable.append("\n");
                }
            }

            binding.tvLog.setText(spannable);
            binding.tvLog.post(() -> {
                if (binding.tvLog.getParent() instanceof ScrollView) {
                    ((ScrollView) binding.tvLog.getParent()).fullScroll(View.FOCUS_DOWN);
                }
            });
        });
    }

    private void scrollToBottom() {
        ActivityAgentChatBinding binding = getBinding();
        if (binding == null) {
            return;
        }

        RecyclerView recyclerView = binding.rvTranscript;
        int lastPosition = transcriptAdapter.getItemCount() - 1;
        if (lastPosition < 0) {
            return;
        }

        recyclerView.stopScroll();
        LinearLayoutManager layoutManager = (LinearLayoutManager) recyclerView.getLayoutManager();
        if (layoutManager == null) {
            return;
        }

        recyclerView.post(() -> {
            layoutManager.scrollToPosition(lastPosition);

            View lastView = layoutManager.findViewByPosition(lastPosition);
            if (lastView != null && lastView.getHeight() > recyclerView.getHeight()) {
                int offset = recyclerView.getHeight() - lastView.getHeight();
                layoutManager.scrollToPositionWithOffset(lastPosition, offset);
            }

            isScrollBottom = true;
        });
    }

    private String capitalizeStateLabel(String rawValue) {
        if (rawValue == null || rawValue.isEmpty()) {
            return "Idle";
        }
        return rawValue.substring(0, 1).toUpperCase(Locale.US) + rawValue.substring(1);
    }
}

class TranscriptAdapter extends ListAdapter<Transcript, RecyclerView.ViewHolder> {

    private static final int VIEW_TYPE_USER = 0;
    private static final int VIEW_TYPE_AGENT = 1;

    protected TranscriptAdapter() {
        super(new TranscriptDiffCallback());
    }

    @Override
    public int getItemViewType(int position) {
        Transcript transcript = getItem(position);
        return transcript != null && transcript.getType() == TranscriptType.AGENT
            ? VIEW_TYPE_AGENT
            : VIEW_TYPE_USER;
    }

    @NonNull
    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        LayoutInflater inflater = LayoutInflater.from(parent.getContext());
        if (viewType == VIEW_TYPE_AGENT) {
            return new AgentViewHolder(ItemTranscriptAgentBinding.inflate(inflater, parent, false));
        }
        return new UserViewHolder(ItemTranscriptUserBinding.inflate(inflater, parent, false));
    }

    @Override
    public void onBindViewHolder(@NonNull RecyclerView.ViewHolder holder, int position) {
        Transcript transcript = getItem(position);
        if (transcript == null) {
            return;
        }

        if (holder instanceof UserViewHolder) {
            ((UserViewHolder) holder).bind(transcript);
        } else if (holder instanceof AgentViewHolder) {
            ((AgentViewHolder) holder).bind(transcript);
        }
    }

    static class UserViewHolder extends RecyclerView.ViewHolder {
        private final ItemTranscriptUserBinding binding;

        UserViewHolder(ItemTranscriptUserBinding binding) {
            super(binding.getRoot());
            this.binding = binding;
        }

        void bind(Transcript transcript) {
            String text = transcript.getText();
            binding.tvTranscriptText.setText(text != null && !text.isEmpty() ? text : "...");
        }
    }

    static class AgentViewHolder extends RecyclerView.ViewHolder {
        private final ItemTranscriptAgentBinding binding;

        AgentViewHolder(ItemTranscriptAgentBinding binding) {
            super(binding.getRoot());
            this.binding = binding;
        }

        void bind(Transcript transcript) {
            String text = transcript.getText();
            binding.tvTranscriptText.setText(text != null && !text.isEmpty() ? text : "...");
        }
    }

    private static class TranscriptDiffCallback extends DiffUtil.ItemCallback<Transcript> {
        @Override
        public boolean areItemsTheSame(@NonNull Transcript oldItem, @NonNull Transcript newItem) {
            return oldItem.getTurnId() == newItem.getTurnId() && oldItem.getType() == newItem.getType();
        }

        @Override
        public boolean areContentsTheSame(@NonNull Transcript oldItem, @NonNull Transcript newItem) {
            return oldItem.equals(newItem);
        }
    }
}
