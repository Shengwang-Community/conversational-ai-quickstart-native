package cn.shengwang.convoai.quickstart.tools;

import android.Manifest;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.provider.Settings;
import androidx.activity.ComponentActivity;
import androidx.activity.result.contract.ActivityResultContract;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.core.content.ContextCompat;

/**
 * PermissionHelp utility class for handling runtime permissions
 */
public class PermissionHelp {
    private final ComponentActivity activity;
    private Runnable granted;
    private Runnable unGranted;
    
    private final androidx.activity.result.ActivityResultLauncher<String> requestPermissionLauncher;
    private final androidx.activity.result.ActivityResultLauncher<String> appSettingLauncher;

    public PermissionHelp(ComponentActivity activity) {
        this.activity = activity;
        
        // Register for permission request result
        this.requestPermissionLauncher = activity.registerForActivityResult(
            new ActivityResultContracts.RequestPermission(),
            isGranted -> {
                Runnable grantedCallback = this.granted;
                Runnable unGrantedCallback = this.unGranted;
                this.granted = null;
                this.unGranted = null;

                if (isGranted) {
                    if (grantedCallback != null) {
                        grantedCallback.run();
                    }
                } else {
                    if (unGrantedCallback != null) {
                        unGrantedCallback.run();
                    }
                }
            }
        );
        
        // Register for app settings result
        this.appSettingLauncher = activity.registerForActivityResult(
            new ActivityResultContract<String, Boolean>() {
                private String input;

                @Override
                public Intent createIntent(Context context, String input) {
                    this.input = input;
                    Intent intent = new Intent();
                    intent.setAction(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                    intent.setData(Uri.parse("package:" + context.getPackageName()));
                    return intent;
                }

                @Override
                public Boolean parseResult(int resultCode, Intent intent) {
                    return ContextCompat.checkSelfPermission(
                        PermissionHelp.this.activity,
                        input != null ? input : ""
                    ) == PackageManager.PERMISSION_GRANTED;
                }
            },
            isGranted -> {
                Runnable grantedCallback = PermissionHelp.this.granted;
                Runnable unGrantedCallback = PermissionHelp.this.unGranted;
                PermissionHelp.this.granted = null;
                PermissionHelp.this.unGranted = null;

                if (isGranted) {
                    if (grantedCallback != null) {
                        grantedCallback.run();
                    }
                } else {
                    if (unGrantedCallback != null) {
                        unGrantedCallback.run();
                    }
                }
            }
        );
    }

    public void checkCameraAndMicPerms(Runnable granted, Runnable unGranted, boolean force) {
        checkCameraPerm(() -> checkMicPerm(granted, unGranted, force), unGranted, force);
    }

    public void checkCameraAndMicPerms(Runnable granted, Runnable unGranted) {
        checkCameraAndMicPerms(granted, unGranted, false);
    }

    public void checkMicPerm(Runnable granted, Runnable unGranted, boolean force) {
        checkPermission(Manifest.permission.RECORD_AUDIO, granted, force, unGranted);
    }

    public void checkMicPerm(Runnable granted, Runnable unGranted) {
        checkMicPerm(granted, unGranted, false);
    }

    public void checkCameraPerm(Runnable granted, Runnable unGranted, boolean force) {
        checkPermission(Manifest.permission.CAMERA, granted, force, unGranted);
    }

    public void checkCameraPerm(Runnable granted, Runnable unGranted) {
        checkCameraPerm(granted, unGranted, false);
    }

    public void checkStoragePerm(Runnable granted, Runnable unGranted, boolean force) {
        checkPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE, () -> {
            checkPermission(Manifest.permission.READ_EXTERNAL_STORAGE, granted, force, unGranted);
        }, force, unGranted);
    }

    public void checkStoragePerm(Runnable granted, Runnable unGranted) {
        checkStoragePerm(granted, unGranted, false);
    }

    private void checkPermission(String perm, Runnable granted, boolean force, Runnable unGranted) {
        if (ContextCompat.checkSelfPermission(activity, perm) == PackageManager.PERMISSION_GRANTED) {
            // You can use the API that requires the permission.
            granted.run();
        } else if (activity.shouldShowRequestPermissionRationale(perm)) {
            // In an educational UI, explain to the user why your app requires this
            // permission for a specific feature to behave as expected, and what
            // features are disabled if it's declined. In this UI, include a
            // "cancel" or "no thanks" button that lets the user continue
            // using your app without granting the permission.
            if (force) {
                launchAppSetting(perm, granted, unGranted);
            } else {
                unGranted.run();
            }
        } else {
            // You can directly ask for the permission.
            // The registered ActivityResultCallback gets the result of this request.
            launchPermissionRequest(perm, granted, unGranted);
        }
    }

    private void launchPermissionRequest(String perm, Runnable granted, Runnable unGranted) {
        this.granted = granted;
        this.unGranted = unGranted;
        requestPermissionLauncher.launch(perm);
    }

    private void launchAppSetting(String perm, Runnable granted, Runnable unGranted) {
        this.granted = granted;
        this.unGranted = unGranted;
        appSettingLauncher.launch(perm);
    }

    public void launchAppSettingForMic(Runnable granted, Runnable unGranted) {
        this.granted = granted;
        this.unGranted = unGranted;
        appSettingLauncher.launch(Manifest.permission.RECORD_AUDIO);
    }

    public void launchAppSettingForCamera(Runnable granted, Runnable unGranted) {
        this.granted = granted;
        this.unGranted = unGranted;
        appSettingLauncher.launch(Manifest.permission.CAMERA);
    }

    public boolean hasMicPerm() {
        return ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED;
    }

    public boolean hasCameraPerm() {
        return ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED;
    }
}

