package cn.shengwang.convoai.quickstart.ui.common;

import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import androidx.activity.OnBackPressedCallback;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.viewbinding.ViewBinding;

/**
 * Base Activity with ViewBinding support and immersive mode configuration
 * @param <VB> ViewBinding type
 */
public abstract class BaseActivity<VB extends ViewBinding> extends AppCompatActivity {

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
        if (supportOnBackPressed()) {
            finish();
        }
    }

    protected abstract VB getViewBinding();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        binding = getViewBinding();
        if (binding == null || binding.getRoot() == null) {
            finish();
            return;
        }
        setContentView(binding.getRoot());
        getOnBackPressedDispatcher().addCallback(this, onBackPressedCallback);
        setupSystemBarsAndCutout(immersiveMode(), usesDarkStatusBarIcons());
        initData();
        initView();
    }

    public ImmersiveMode immersiveMode() {
        return ImmersiveMode.SEMI_IMMERSIVE;
    }

    public boolean supportOnBackPressed() {
        return true;
    }

    /**
     * Determines the status bar icons/text color
     * @return true for dark icons (suitable for light backgrounds), false for light icons (suitable for dark backgrounds)
     */
    public boolean usesDarkStatusBarIcons() {
        return false;
    }

    @Override
    public void finish() {
        onBackPressedCallback.remove();
        super.finish();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        binding = null;
    }

    public void initData() {}

    /**
     * Initialize the view.
     */
    protected abstract void initView();

    public void setOnApplyWindowInsetsListener(View view) {
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
    protected void setupSystemBarsAndCutout(ImmersiveMode immersiveMode, boolean lightStatusBar) {
        // Step 1: Set up basic Edge-to-Edge display
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+
            getWindow().setDecorFitsSystemWindows(false);
            androidx.core.view.WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
            if (controller != null) {
                controller.setAppearanceLightStatusBars(lightStatusBar);
            }
        } else {
            int flags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION;

            if (lightStatusBar) {
                flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
            }

            getWindow().getDecorView().setSystemUiVisibility(flags);
        }

        // Step 2: Set system bar transparency
        getWindow().setStatusBarColor(Color.TRANSPARENT);
        getWindow().setNavigationBarColor(Color.TRANSPARENT);

        // Step 3: Handle notch screens
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            WindowManager.LayoutParams params = getWindow().getAttributes();
            params.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            getWindow().setAttributes(params);
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
                    WindowInsetsController controller = getWindow().getInsetsController();
                    if (controller != null) {
                        controller.hide(WindowInsets.Type.navigationBars());
                        controller.show(WindowInsets.Type.statusBars());
                        controller.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
                    }
                } else {
                    int flags = getWindow().getDecorView().getSystemUiVisibility()
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;
                    getWindow().getDecorView().setSystemUiVisibility(flags);
                }
                break;

            case FULLY_IMMERSIVE:
                // Hide all system bars
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    WindowInsetsController controller = getWindow().getInsetsController();
                    if (controller != null) {
                        controller.hide(WindowInsets.Type.systemBars());
                        controller.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
                    }
                } else {
                    int flags = getWindow().getDecorView().getSystemUiVisibility()
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;
                    getWindow().getDecorView().setSystemUiVisibility(flags);
                }
                break;
        }
    }

    /**
     * Immersive mode types
     */
    public enum ImmersiveMode {
        /**
         * Content extends under system bars, but system bars remain visible
         */
        EDGE_TO_EDGE,

        /**
         * Hide navigation bar, show status bar
         */
        SEMI_IMMERSIVE,

        /**
         * Hide all system bars, fully immersive
         */
        FULLY_IMMERSIVE
    }
}

