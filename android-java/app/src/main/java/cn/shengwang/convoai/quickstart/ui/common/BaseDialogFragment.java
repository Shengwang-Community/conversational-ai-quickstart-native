package cn.shengwang.convoai.quickstart.ui.common;

import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.Build;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.widget.FrameLayout;
import androidx.activity.OnBackPressedCallback;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.fragment.app.DialogFragment;
import androidx.viewbinding.ViewBinding;

/**
 * Base DialogFragment with ViewBinding support and immersive mode configuration
 * @param <B> ViewBinding type
 */
public abstract class BaseDialogFragment<B extends ViewBinding> extends DialogFragment {

    protected B binding;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = getViewBinding(inflater, container);
        return binding != null ? binding.getRoot() : null;
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }

    protected abstract B getViewBinding(LayoutInflater inflater, ViewGroup container);

    @Override
    public void onViewCreated(View view, Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        setupSystemBarsAndCutout(immersiveMode(), usesDarkStatusBarIcons());
        if (getDialog() != null && getDialog().getWindow() != null) {
            getDialog().getWindow().setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
        }
        if (getActivity() != null && getActivity().getOnBackPressedDispatcher() != null) {
            getActivity().getOnBackPressedDispatcher().addCallback(getViewLifecycleOwner(), new OnBackPressedCallback(true) {
                @Override
                public void handleOnBackPressed() {
                    onHandleOnBackPressed();
                }
            });
        }
    }

    /**
     * Determines the immersive mode type to use
     */
    public BaseActivity.ImmersiveMode immersiveMode() {
        return BaseActivity.ImmersiveMode.SEMI_IMMERSIVE;
    }

    /**
     * Determines the status bar icons/text color
     * @return true for dark icons (suitable for light backgrounds), false for light icons (suitable for dark backgrounds)
     */
    public boolean usesDarkStatusBarIcons() {
        return false;
    }

    protected void setOnApplyWindowInsets(View root) {
        if (getDialog() != null && getDialog().getWindow() != null) {
            ViewCompat.setOnApplyWindowInsetsListener(getDialog().getWindow().getDecorView(), (v, insets) -> {
                androidx.core.graphics.Insets inset = insets.getInsets(WindowInsetsCompat.Type.systemBars());
                root.setPadding(inset.left, 0, inset.right, inset.bottom + root.getPaddingBottom());
                return WindowInsetsCompat.CONSUMED;
            });
        }
    }

    public void onHandleOnBackPressed() {
        dismiss();
    }

    /**
     * Sets up immersive display and notch screen adaptation
     * @param immersiveMode Type of immersive mode
     * @param lightStatusBar Whether to use dark status bar icons
     */
    protected void setupSystemBarsAndCutout(BaseActivity.ImmersiveMode immersiveMode, boolean lightStatusBar) {
        if (getDialog() == null || getDialog().getWindow() == null) {
            return;
        }

        android.view.Window window = getDialog().getWindow();
        
        // Step 1: Set up basic Edge-to-Edge display
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+
            window.setDecorFitsSystemWindows(false);
            androidx.core.view.WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(window, window.getDecorView());
            if (controller != null) {
                controller.setAppearanceLightStatusBars(lightStatusBar);
            }
        } else {
            // Android 10 and below
            int flags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION;

            if (lightStatusBar && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
            }

            window.getDecorView().setSystemUiVisibility(flags);
        }

        // Step 2: Set system bar transparency
        window.setStatusBarColor(Color.TRANSPARENT);
        window.setNavigationBarColor(Color.TRANSPARENT);

        // Step 3: Handle notch screens
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            WindowManager.LayoutParams params = window.getAttributes();
            params.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            window.setAttributes(params);
        }

        // Step 4: Set system UI visibility based on immersive mode
        switch (immersiveMode) {
            case EDGE_TO_EDGE:
                // Do not hide any system bars, only extend content to full screen
                // Already set in step 1
                break;

            case SEMI_IMMERSIVE:
                // Hide navigation bar, show status bar
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    WindowInsetsController controller = window.getDecorView().getWindowInsetsController();
                    if (controller != null) {
                        controller.hide(WindowInsets.Type.navigationBars());
                        controller.show(WindowInsets.Type.statusBars());
                        controller.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
                    }
                } else {
                    int flags = window.getDecorView().getSystemUiVisibility()
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;
                    window.getDecorView().setSystemUiVisibility(flags);
                }
                break;

            case FULLY_IMMERSIVE:
                // Hide all system bars
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    WindowInsetsController controller = window.getDecorView().getWindowInsetsController();
                    if (controller != null) {
                        controller.hide(WindowInsets.Type.systemBars());
                        controller.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
                    }
                } else {
                    int flags = window.getDecorView().getSystemUiVisibility()
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;
                    window.getDecorView().setSystemUiVisibility(flags);
                }
                break;
        }
    }

    /**
     * Force stronger immersive mode to prevent navigation bar from showing during user interaction
     */
    public void forceImmersiveMode() {
        if (getDialog() == null || getDialog().getWindow() == null) {
            return;
        }

        View decorView = getDialog().getWindow().getDecorView();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+: Use stronger immersive mode
            WindowInsetsController controller = decorView.getWindowInsetsController();
            if (controller != null) {
                controller.hide(WindowInsets.Type.systemBars());
                controller.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
        } else {
            // Android 10 and below: Use deprecated flags with stronger settings
            int flags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    | View.SYSTEM_UI_FLAG_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;
            decorView.setSystemUiVisibility(flags);
        }
    }

    /**
     * Extension function equivalent: Set dialog width as a ratio of screen width
     */
    public static void setDialogWidth(View view, float widthRatio) {
        ViewGroup.LayoutParams params = view.getLayoutParams();
        if (params instanceof FrameLayout.LayoutParams) {
            FrameLayout.LayoutParams frameParams = (FrameLayout.LayoutParams) params;
            frameParams.width = (int) (view.getResources().getDisplayMetrics().widthPixels * widthRatio);
            frameParams.height = ViewGroup.LayoutParams.WRAP_CONTENT;
            view.setLayoutParams(frameParams);
        }
    }
}

