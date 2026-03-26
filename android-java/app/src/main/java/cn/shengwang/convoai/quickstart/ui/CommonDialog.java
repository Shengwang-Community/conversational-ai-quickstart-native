package cn.shengwang.convoai.quickstart.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import cn.shengwang.convoai.quickstart.ui.common.BaseActivity;
import cn.shengwang.convoai.quickstart.ui.common.BaseDialogFragment;
import cn.shengwang.convoai.quickstart.databinding.DialogCommonLayoutBinding;

/**
 * CommonDialog - A reusable dialog fragment with title, content, and buttons
 */
public class CommonDialog extends BaseDialogFragment<DialogCommonLayoutBinding> {

    // Dialog configuration class
    private static class DialogConfig {
        String title;
        String content;
        String positiveText;
        String negativeText;
        boolean showNegative = true;
        boolean cancelable = true;
        BaseActivity.ImmersiveMode immersiveMode = BaseActivity.ImmersiveMode.SEMI_IMMERSIVE;
        Runnable onPositiveClick;
        Runnable onNegativeClick;
    }

    private DialogConfig config = new DialogConfig();

    @Override
    public BaseActivity.ImmersiveMode immersiveMode() {
        return config.immersiveMode;
    }

    @Override
    protected DialogCommonLayoutBinding getViewBinding(LayoutInflater inflater, ViewGroup container) {
        return DialogCommonLayoutBinding.inflate(inflater, container, false);
    }

    @Override
    public void onViewCreated(View view, Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        setupDialog();
    }

    private void setupDialog() {
        if (binding == null) {
            return;
        }

        // Set dialog width to 84% of screen width
        BaseDialogFragment.setDialogWidth(binding.getRoot(), 0.84f);

        // Setup views
        setupBasicViews();
        setupClickListeners();
    }

    private void setupBasicViews() {
        if (binding == null) {
            return;
        }

        binding.tvTitle.setText(config.title);
        binding.tvContent.setText(config.content);
        binding.btnPositive.setText(config.positiveText);
        binding.btnNegative.setText(config.negativeText);
        binding.btnNegative.setVisibility(config.showNegative ? View.VISIBLE : View.GONE);
    }

    private void setupClickListeners() {
        if (binding == null) {
            return;
        }

        binding.btnPositive.setOnClickListener(v -> {
            if (config.onPositiveClick != null) {
                config.onPositiveClick.run();
            }
            dismiss();
        });

        binding.btnNegative.setOnClickListener(v -> {
            if (config.onNegativeClick != null) {
                config.onNegativeClick.run();
            }
            dismiss();
        });
    }

    /**
     * Builder class for creating CommonDialog instances
     */
    public static class Builder {
        private DialogConfig config = new DialogConfig();

        public Builder setTitle(String title) {
            config.title = title;
            return this;
        }

        public Builder setContent(String content) {
            config.content = content;
            return this;
        }

        public Builder setPositiveButton(String text, Runnable onClick) {
            config.positiveText = text;
            config.onPositiveClick = onClick;
            return this;
        }

        public Builder setPositiveButton(String text) {
            return setPositiveButton(text, null);
        }

        public Builder setNegativeButton(String text, Runnable onClick) {
            config.negativeText = text;
            config.onNegativeClick = onClick;
            config.showNegative = true;
            return this;
        }

        public Builder setNegativeButton(String text) {
            return setNegativeButton(text, null);
        }

        public Builder setCancelable(boolean cancelable) {
            config.cancelable = cancelable;
            return this;
        }

        public Builder setImmersiveMode(BaseActivity.ImmersiveMode mode) {
            config.immersiveMode = mode;
            return this;
        }

        public CommonDialog build() {
            CommonDialog dialog = new CommonDialog();
            dialog.config = this.config;
            dialog.setCancelable(config.cancelable);
            return dialog;
        }
    }
}
