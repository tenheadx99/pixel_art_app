import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pixel_art_app/config/app_constants.dart';
import 'package:pixel_art_app/data/services/remote_config_service.dart';

/// Manages Google Play In-App Updates (Flexible & Immediate) with smart fallback.
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._();
  factory AppUpdateService() => _instance;
  AppUpdateService._();

  bool _isUpdateCheckInProgress = false;

  /// Checks for available updates via Google Play In-App Updates API,
  /// with automatic fallback to custom update dialog if Play Core API fails.
  Future<void> checkForUpdate({
    required BuildContext context,
    bool forceImmediate = false,
  }) async {
    if (!Platform.isAndroid) return;
    if (!context.mounted) return;
    if (_isUpdateCheckInProgress) return;

    _isUpdateCheckInProgress = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (!context.mounted) return;
      developer.log(
        'InAppUpdate info: availability=${info.updateAvailability}, flexible=${info.flexibleUpdateAllowed}, immediate=${info.immediateUpdateAllowed}, code=${info.availableVersionCode}',
        name: 'AppUpdateService',
      );

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (forceImmediate || info.immediateUpdateAllowed) {
          try {
            await InAppUpdate.performImmediateUpdate();
            return;
          } catch (e) {
            developer.log('Immediate update failed, falling back to flexible/dialog: $e', name: 'AppUpdateService');
          }
        }

        if (!context.mounted) return;

        // Try Flexible In-App Update
        try {
          final result = await InAppUpdate.startFlexibleUpdate();
          if (result == AppUpdateResult.success) {
            if (context.mounted) {
              _showUpdateDownloadedSnackBar(context);
            } else {
              try {
                await InAppUpdate.completeFlexibleUpdate();
              } catch (e) {
                developer.log('Complete flexible update failed: $e', name: 'AppUpdateService');
              }
            }
            return;
          }
        } catch (e) {
          developer.log('Flexible update failed: $e, showing fallback dialog', name: 'AppUpdateService');
        }

        // If in-app update UI didn't show, show custom fallback dialog
        if (context.mounted) {
          _showFallbackUpdateDialog(context);
        }
      } else {
        // Play API says no update via Play Core, check Remote Config version fallback
        if (context.mounted) {
          await _checkRemoteConfigFallback(context);
        }
      }
    } catch (e, stack) {
      developer.log(
        'InAppUpdate.checkForUpdate failed (e.g. sideloaded APK): $e',
        name: 'AppUpdateService',
        error: e,
        stackTrace: stack,
      );
      // Fallback: check Remote Config version vs PackageInfo version
      if (context.mounted) {
        await _checkRemoteConfigFallback(context);
      }
    } finally {
      _isUpdateCheckInProgress = false;
    }
  }

  Future<void> _checkRemoteConfigFallback(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final minVersion = RemoteConfigService().minRequiredVersion;

      if (_isVersionOlder(currentVersion, minVersion)) {
        if (context.mounted) {
          _showFallbackUpdateDialog(context);
        }
      }
    } catch (_) {}
  }

  static bool _isVersionOlder(String current, String required) {
    final currentClean = current.split('+')[0];
    final requiredClean = required.split('+')[0];

    final currentParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final requiredParts = requiredClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    while (currentParts.length < 3) {
      currentParts.add(0);
    }
    while (requiredParts.length < 3) {
      requiredParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (currentParts[i] < requiredParts[i]) return true;
      if (currentParts[i] > requiredParts[i]) return false;
    }
    return false;
  }

  void _showFallbackUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Color(0xFF8A2BE2)),
            SizedBox(width: 10),
            Text('Update Available'),
          ],
        ),
        content: const Text(
          'A new version of the app is available on the Play Store. Update now to get the latest features and improvements!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8A2BE2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final marketUri = Uri.parse('market://details?id=${AppConstants.appStoreId}');
              final webUri = Uri.parse(AppConstants.appStoreUrl);
              try {
                if (await canLaunchUrl(marketUri)) {
                  await launchUrl(marketUri, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(webUri, mode: LaunchMode.externalApplication);
                }
              } catch (_) {}
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  void _showUpdateDownloadedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('An update has been downloaded.'),
        duration: const Duration(days: 1),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'RESTART',
          onPressed: () {
            InAppUpdate.completeFlexibleUpdate().catchError((e) {
              developer.log('Failed to complete flexible update: $e', name: 'AppUpdateService');
            });
          },
        ),
      ),
    );
  }
}
