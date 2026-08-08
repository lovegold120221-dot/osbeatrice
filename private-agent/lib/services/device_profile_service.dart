import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import '../models/device_profile.dart';

/// Fetches and caches the Android device profile via the existing native
/// accessibility MethodChannel.
class DeviceProfileService {
  static const MethodChannel _channel = MethodChannel('ai.eburon.beatrice/accessibility');

  DeviceProfile? _cached;

  /// Fetches the device profile from the native side. Caches the result so
  /// subsequent calls are cheap.
  Future<DeviceProfile> getProfile() async {
    if (_cached != null) return _cached!;

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDeviceProfile');
      if (result == null) {
        throw Exception('Native side returned null device profile');
      }
      final map = result.cast<String, dynamic>();
      _cached = DeviceProfile.fromJson(map);
      return _cached!;
    } catch (e) {
      developer.log('DeviceProfileService failed: $e', name: 'BeatriceOS');
      // Return a minimal fallback so the agent can still function.
      _cached = DeviceProfile(
        manufacturer: 'unknown',
        brand: 'unknown',
        model: 'unknown',
        device: 'unknown',
        sdkInt: 0,
        locale: 'en',
        display: const DisplayMetrics(widthPixels: 0, heightPixels: 0, density: 0, densityDpi: 0),
        capabilities: const Capabilities(
          accessibilityEnabled: false,
          screenshotSupported: false,
          shizukuAvailable: false,
          shizukuPermission: false,
          overlayPermission: false,
        ),
        capturedAt: DateTime.now(),
      );
      return _cached!;
    }
  }

  void invalidateCache() => _cached = null;
}
