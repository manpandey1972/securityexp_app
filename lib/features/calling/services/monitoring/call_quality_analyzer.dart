import 'package:livekit_client/livekit_client.dart';
import 'package:securityexperts_app/features/calling/services/interfaces/room_service.dart';

/// Analyzes call quality metrics from LiveKit participants.
///
/// Extracts stats collection and quality mapping logic from LiveKitService
/// for better separation of concerns and testability.
class CallQualityAnalyzer {
  /// Collect quality stats from local and remote participants.
  ///
  /// Returns [CallQualityStats] with RTT, packet loss, jitter, and quality level.
  Future<CallQualityStats> collectStats({
    required LocalParticipant? localParticipant,
    required RemoteParticipant? remoteParticipant,
  }) async {
    // Get connection quality from participants
    final localQuality =
        localParticipant?.connectionQuality ?? ConnectionQuality.unknown;
    final remoteQuality =
        remoteParticipant?.connectionQuality ?? ConnectionQuality.unknown;

    // Use the worse of local/remote quality
    final worstQuality = _getWorseQuality(localQuality, remoteQuality);
    final qualityLevel = mapConnectionQuality(worstQuality);

    // Stats variables
    double? rtt;
    double? packetLoss;
    double? jitter;

    // Collect stats from local video track (sender stats)
    final localVideoTrack =
        localParticipant?.videoTrackPublications.firstOrNull?.track;
    if (localVideoTrack != null) {
      final senderStats = await localVideoTrack.getSenderStats();
      if (senderStats.isNotEmpty) {
        final stats = senderStats.first;
        rtt = stats.roundTripTime?.toDouble();
        packetLoss = stats.packetsLost?.toDouble();
      }
    }

    // Collect receiver stats from remote video
    final remoteVideoTrack =
        remoteParticipant?.videoTrackPublications.firstOrNull?.track;
    if (remoteVideoTrack is RemoteVideoTrack) {
      final receiverStats = await remoteVideoTrack.getReceiverStats();
      if (receiverStats != null) {
        jitter = receiverStats.jitter?.toDouble();
        // Use receiver packet loss if sender stats weren't available
        packetLoss ??= receiverStats.packetsLost?.toDouble();
      }
    }

    return CallQualityStats(
      quality: qualityLevel,
      rttMs: rtt != null ? rtt * 1000 : null, // Convert to ms
      packetLossPercent: packetLoss,
      jitterMs: jitter != null ? jitter * 1000 : null, // Convert to ms
      sendBitrateKbps: null, // Not directly available in stats
      recvBitrateKbps: null, // Not directly available in stats
      timestamp: DateTime.now(),
    );
  }

  /// Compare two connection qualities and return the worse one.
  ConnectionQuality _getWorseQuality(ConnectionQuality a, ConnectionQuality b) {
    const order = [
      ConnectionQuality.poor,
      ConnectionQuality.good,
      ConnectionQuality.excellent,
      ConnectionQuality.unknown,
    ];
    final aIndex = order.indexOf(a);
    final bIndex = order.indexOf(b);
    return aIndex < bIndex ? a : b;
  }

  /// Map LiveKit's ConnectionQuality to our CallQualityLevel.
  CallQualityLevel mapConnectionQuality(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return CallQualityLevel.excellent;
      case ConnectionQuality.good:
        return CallQualityLevel.good;
      case ConnectionQuality.poor:
        return CallQualityLevel.poor;
      case ConnectionQuality.unknown:
      default:
        return CallQualityLevel.unknown;
    }
  }

  /// Check if stats indicate poor quality that might need user notification.
  bool isPoorQuality(CallQualityStats stats) {
    if (stats.quality == CallQualityLevel.poor) return true;
    if (stats.packetLossPercent != null && stats.packetLossPercent! > 5) {
      return true;
    }
    if (stats.rttMs != null && stats.rttMs! > 300) return true;
    return false;
  }

  /// Get a human-readable quality description.
  String getQualityDescription(CallQualityStats stats) {
    switch (stats.quality) {
      case CallQualityLevel.excellent:
        return 'Excellent connection';
      case CallQualityLevel.good:
        return 'Good connection';
      case CallQualityLevel.fair:
        return 'Fair connection - may experience some issues';
      case CallQualityLevel.poor:
        return 'Poor connection - call quality may be affected';
      case CallQualityLevel.unknown:
        return 'Checking connection...';
    }
  }
}
