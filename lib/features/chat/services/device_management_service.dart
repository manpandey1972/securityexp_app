import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/data/repositories/crypto/key_store_repository.dart';
import 'package:securityexperts_app/data/repositories/crypto/prekey_repository.dart';

/// Service for managing E2EE registered devices.
///
/// Provides:
/// - List all registered devices for the current user
/// - Revoke (deregister) a device
/// - Identify the current device
/// - Device count and limits
///
/// Usage:
/// ```dart
/// final service = sl<DeviceManagementService>();
/// final devices = await service.getDevices('user_id');
/// await service.revokeDevice(userId: 'user_id', deviceId: 'old_device');
/// ```
class DeviceManagementService {
  final PreKeyRepository _preKeyRepo;
  // ignore: unused_field
  final IKeyStoreRepository _keyStore; // Reserved for local key operations
  final AppLogger _log;

  static const _tag = 'DeviceManagement';

  /// Maximum number of devices allowed per user.
  static const maxDevices = 5;

  /// The current device's ID (set by E2eeInitializationService).
  String? _currentDeviceId;

  DeviceManagementService({
    required PreKeyRepository preKeyRepo,
    required IKeyStoreRepository keyStore,
    required AppLogger log,
  })  : _preKeyRepo = preKeyRepo,
        _keyStore = keyStore,
        _log = log;

  /// Set the current device ID (called by E2eeInitializationService).
  void setCurrentDeviceId(String deviceId) {
    _currentDeviceId = deviceId;
  }

  /// Get the current device ID.
  String? get currentDeviceId => _currentDeviceId;

  // =========================================================================
  // Device Listing
  // =========================================================================

  /// Get all registered devices for [userId].
  ///
  /// Returns a list of [DeviceInfo] with metadata about each device.
  Future<List<DeviceInfo>> getDevices(String userId) async {
    try {
      final bundles = await _preKeyRepo.getDevices(userId);

      return bundles.map((bundle) => DeviceInfo(
        deviceId: bundle.deviceId,
        deviceName: bundle.deviceName,
        identityKeyFingerprint: _fingerprint(bundle.identityKey),
        isCurrentDevice: bundle.deviceId == _currentDeviceId,
        registrationId: bundle.registrationId,
      )).toList();
    } catch (e) {
      _log.error('Failed to get devices: $e', tag: _tag);
      return [];
    }
  }

  /// Get the number of registered devices for [userId].
  Future<int> getDeviceCount(String userId) async {
    try {
      final devices = await _preKeyRepo.getDevices(userId);
      return devices.length;
    } catch (e) {
      _log.error('Failed to get device count: $e', tag: _tag);
      return 0;
    }
  }

  /// Check if the user can register more devices.
  Future<bool> canRegisterMoreDevices(String userId) async {
    final count = await getDeviceCount(userId);
    return count < maxDevices;
  }

  // =========================================================================
  // Device Revocation
  // =========================================================================

  /// Revoke (deregister) a device.
  ///
  /// Removes the device's PreKeyBundle from Firestore.
  /// Cannot revoke the current device through this method —
  /// use E2eeInitializationService.cleanup() instead.
  ///
  /// Returns true if the device was successfully revoked.
  Future<bool> revokeDevice({
    required String userId,
    required String deviceId,
  }) async {
    if (deviceId == _currentDeviceId) {
      _log.warning(
        'Cannot revoke current device through device management',
        tag: _tag,
      );
      return false;
    }

    try {
      await _preKeyRepo.deregisterDevice(
        userId: userId,
        deviceId: deviceId,
      );

      _log.info('Device $deviceId revoked for user $userId', tag: _tag);
      return true;
    } catch (e) {
      _log.error('Failed to revoke device $deviceId: $e', tag: _tag);
      return false;
    }
  }

  /// Revoke all devices except the current one.
  ///
  /// Useful for security resets.
  Future<int> revokeAllOtherDevices(String userId) async {
    try {
      final devices = await _preKeyRepo.getDevices(userId);
      var revokedCount = 0;

      for (final device in devices) {
        if (device.deviceId != _currentDeviceId) {
          await _preKeyRepo.deregisterDevice(
            userId: userId,
            deviceId: device.deviceId,
          );
          revokedCount++;
        }
      }

      _log.info('Revoked $revokedCount devices for user $userId', tag: _tag);
      return revokedCount;
    } catch (e) {
      _log.error('Failed to revoke other devices: $e', tag: _tag);
      return 0;
    }
  }

  // =========================================================================
  // Helpers
  // =========================================================================

  /// Generate a short fingerprint from an identity key for display.
  ///
  /// Takes the first 8 bytes of the key and formats as hex pairs.
  String _fingerprint(dynamic identityKey) {
    if (identityKey is List<int> && identityKey.length >= 8) {
      return identityKey
          .take(8)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(':');
    }
    return 'unknown';
  }
}

/// Information about a registered device.
class DeviceInfo {
  /// Unique device identifier.
  final String deviceId;

  /// Human-readable device name.
  final String deviceName;

  /// Short hex fingerprint of the device's identity key.
  final String identityKeyFingerprint;

  /// Whether this is the current device.
  final bool isCurrentDevice;

  /// Registration ID for this device.
  final int registrationId;

  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.identityKeyFingerprint,
    required this.isCurrentDevice,
    required this.registrationId,
  });

  @override
  String toString() =>
      'DeviceInfo($deviceId, $deviceName, current: $isCurrentDevice)';
}
