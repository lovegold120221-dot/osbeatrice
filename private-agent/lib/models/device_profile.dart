import 'dart:convert';

/// Runtime Android device profile and capability snapshot.
///
/// Used to choose the correct app adapter (Samsung, Pixel, generic) and to
/// decide which verifiers can be used.
class DeviceProfile {
  final String manufacturer;
  final String brand;
  final String model;
  final String device;
  final int sdkInt;
  final String? androidRelease;
  final String? securityPatch;
  final String locale;
  final DisplayMetrics display;
  final Capabilities capabilities;
  final DateTime capturedAt;

  const DeviceProfile({
    required this.manufacturer,
    required this.brand,
    required this.model,
    required this.device,
    required this.sdkInt,
    this.androidRelease,
    this.securityPatch,
    required this.locale,
    required this.display,
    required this.capabilities,
    required this.capturedAt,
  });

  Map<String, dynamic> toJson() => {
        'manufacturer': manufacturer,
        'brand': brand,
        'model': model,
        'device': device,
        'sdkInt': sdkInt,
        'androidRelease': androidRelease,
        'securityPatch': securityPatch,
        'locale': locale,
        'display': display.toJson(),
        'capabilities': capabilities.toJson(),
        'capturedAt': capturedAt.millisecondsSinceEpoch,
      };

  factory DeviceProfile.fromJson(Map<String, dynamic> json) {
    return DeviceProfile(
      manufacturer: json['manufacturer'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      device: json['device'] as String? ?? '',
      sdkInt: (json['sdkInt'] as num?)?.toInt() ?? 0,
      androidRelease: json['androidRelease'] as String?,
      securityPatch: json['securityPatch'] as String?,
      locale: json['locale'] as String? ?? '',
      display: DisplayMetrics.fromJson(
        (json['display'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {},
      ),
      capabilities: Capabilities.fromJson(
        (json['capabilities'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {},
      ),
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['capturedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  String toRawJson() => jsonEncode(toJson());
}

class DisplayMetrics {
  final int widthPixels;
  final int heightPixels;
  final double density;
  final double densityDpi;

  const DisplayMetrics({
    required this.widthPixels,
    required this.heightPixels,
    required this.density,
    required this.densityDpi,
  });

  Map<String, dynamic> toJson() => {
        'widthPixels': widthPixels,
        'heightPixels': heightPixels,
        'density': density,
        'densityDpi': densityDpi,
      };

  factory DisplayMetrics.fromJson(Map<String, dynamic> json) {
    return DisplayMetrics(
      widthPixels: (json['widthPixels'] as num?)?.toInt() ?? 0,
      heightPixels: (json['heightPixels'] as num?)?.toInt() ?? 0,
      density: (json['density'] as num?)?.toDouble() ?? 0.0,
      densityDpi: (json['densityDpi'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Capabilities {
  final bool accessibilityEnabled;
  final bool screenshotSupported;
  final bool shizukuAvailable;
  final bool shizukuPermission;
  final bool overlayPermission;

  const Capabilities({
    required this.accessibilityEnabled,
    required this.screenshotSupported,
    required this.shizukuAvailable,
    required this.shizukuPermission,
    required this.overlayPermission,
  });

  Map<String, dynamic> toJson() => {
        'accessibilityEnabled': accessibilityEnabled,
        'screenshotSupported': screenshotSupported,
        'shizukuAvailable': shizukuAvailable,
        'shizukuPermission': shizukuPermission,
        'overlayPermission': overlayPermission,
      };

  factory Capabilities.fromJson(Map<String, dynamic> json) {
    return Capabilities(
      accessibilityEnabled: json['accessibilityEnabled'] == true,
      screenshotSupported: json['screenshotSupported'] == true,
      shizukuAvailable: json['shizukuAvailable'] == true,
      shizukuPermission: json['shizukuPermission'] == true,
      overlayPermission: json['overlayPermission'] == true,
    );
  }
}
