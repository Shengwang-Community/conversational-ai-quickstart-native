package cn.shengwang.convoai.quickstart.ui.common;

import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import androidx.activity.OnBackPressedCallback;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.fragment.app.Fragment;
import androidx.viewbinding.ViewBinding;

/**
 * Base Fragment with ViewBinding support and immersive mode configuration
 * @param <VB> ViewBinding type
 */
public abstract class BaseFragment<VB extends ViewBinding> extends Fragment {

    private VB binding;
    protected VB getBinding() {
        return binding;
    }

    private final OnBackPressedCallback onBackPressedCallback = new OnBackPressedCallback(true) {
        @Override
        public void handleOnBackPressed() {
            onHandleOnBackPressed();
        }
    };

    public void onHandleOnBackPressed() {
        if (getActivity() != null) {
            getActivity().finish();
        }
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        binding = getViewBinding(inflater, container);
        return binding != null ? binding.getRoot() : null;
    }

    @Override
    public void onViewCreated(View view, Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        if (getActivity() != null && getActivity().getOnBackPressedDispatcher() != null) {
            getActivity().getOnBackPressedDispatcher().addCallback(getViewLifecycleOwner(), onBackPressedCallback);
        }
        initData();
        initView();
    }

    public void initData() {}

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        onBackPressedCallback.remove();
        binding = null;
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

    /**
     * Get the view binding for the fragment
     */
    protected abstract VB getViewBinding(LayoutInflater inflater, ViewGroup container);

    /**
     * Initialize the view.
     */
    public void initView() {}

    protected void setOnApplyWindowInsets(View view) {
        ViewCompat.setOnApplyWindowInsetsListener(view, (v, insets) -> {
            int systemBarsType = WindowInsetsCompat.Type.systemBars();
            androidx.core.graphics.Insets systemBars = insets.getInsets(systemBarsType);
            view.setPaddingRelative(
                systemBars.left + v.getPaddingLeft(),
                systemBars.top,
                systemBars.right + v.getPaddingRight(),
                systemBars.bottom
            );
            return insets;
        });
    }

    /**
     * Sets up immersive display and notch screen adaptation
     * @param immersiveMode Type of immersive mode
     * @param lightStatusBar Whether to use dark status bar icons
     */
    protected void setupSystemBarsAndCutout(BaseActivity.ImmersiveMode immersiveMode, boolean lightStatusBar) {
        if (getActivity() == null || getActivity().getWindow() == null) {
            return;
        }

        android.view.Window window = getActivity().getWindow();
        
        // Step 1: Set up basic Edge-to-Edge display
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+
            window.setDecorFitsSystemWindows(false);
            androidx.core.view.WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(window, window.getDecorView());
            if (controller != null) {
                controller.setAppearanceLightStatusBars(lightStatusBar);
            }
        } else {
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

        // Step 3: Set system UI visibility based on immersive mode
        switch (immersiveMode) {
            case EDGE_TO_EDGE:
                // Do not hide any system bars, only extend content to full screen
                // Already set in step 1
                break;

            case SEMI_IMMERSIVE:
                // Hide navigation bar, show status bar
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    WindowInsetsController controller = window.getInsetsController();
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
                    WindowInsetsController controller = window.getInsetsController();
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
}

