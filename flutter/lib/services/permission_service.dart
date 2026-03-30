import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> ensureMicrophoneGranted(BuildContext context) async {
    // Check current status
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    // Directly request system permission (no local dialog first)
    status = await Permission.microphone.request();
    if (status.isGranted) return true;

    // If denied or permanently denied, show dialog to guide user to settings
    if (status.isDenied || status.isPermanentlyDenied || status.isRestricted) {
      if (!context.mounted) return false;
      final goSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('需要麦克风权限'),
          content: const Text('麦克风权限未授予，请在系统设置中开启后继续。'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('去设置')),
          ],
        ),
      );
      if (goSettings == true) {
        await openAppSettings();
        // Re-check after returning from settings
        final again = await Permission.microphone.status;
        return again.isGranted;
      }
    }
    return false;
  }
}
