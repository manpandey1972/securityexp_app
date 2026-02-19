import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Network quality levels
enum NetworkQuality {
  excellent,
  good,
  fair,
  poor,
  disconnected;

  String get label {
    switch (this) {
      case NetworkQuality.excellent:
        return 'Excellent';
      case NetworkQuality.good:
        return 'Good';
      case NetworkQuality.fair:
        return 'Fair';
      case NetworkQuality.poor:
        return 'Poor';
      case NetworkQuality.disconnected:
        return 'Disconnected';
    }
  }

  String get emoji {
    switch (this) {
      case NetworkQuality.excellent:
        return '🟢';
      case NetworkQuality.good:
        return '🟡';
      case NetworkQuality.fair:
        return '🟠';
      case NetworkQuality.poor:
        return '🔴';
      case NetworkQuality.disconnected:
        return '❌';
    }
  }
}

/// Network quality metrics
class NetworkMetrics {
  final double? packetLoss; // Percentage (0-100)
  final double? jitter; // Milliseconds
  final double? latency; // Milliseconds (RTT)
  final double? bandwidth; // Kbps
  final DateTime timestamp;

  NetworkMetrics({
    this.packetLoss,
    this.jitter,
    this.latency,
    this.bandwidth,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Determine quality based on metrics
  NetworkQuality get quality {
    // If no metrics, assume disconnected
    if (packetLoss == null && jitter == null && latency == null) {
      return NetworkQuality.disconnected;
    }

    // Check packet loss (most critical)
    if (packetLoss != null && packetLoss! > 10) {
      return NetworkQuality.poor;
    }
    if (packetLoss != null && packetLoss! > 5) {
      return NetworkQuality.fair;
    }

    // Check latency
    if (latency != null && latency! > 300) {
      return NetworkQuality.poor;
    }
    if (latency != null && latency! > 200) {
      return NetworkQuality.fair;
    }

    // Check jitter
    if (jitter != null && jitter! > 50) {
      return NetworkQuality.fair;
    }

    // Good thresholds
    if (latency != null &&
        latency! < 100 &&
        (packetLoss == null || packetLoss! < 2)) {
      return NetworkQuality.excellent;
    }

    return NetworkQuality.good;
  }

  Map<String, dynamic> toJson() => {
    'packetLoss': packetLoss,
    'jitter': jitter,
    'latency': latency,
    'bandwidth': bandwidth,
    'quality': quality.name,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() {
    return 'NetworkMetrics(quality: ${quality.label}, '
        'packetLoss: ${packetLoss?.toStringAsFixed(2)}%, '
        'jitter: ${jitter?.toStringAsFixed(1)}ms, '
        'latency: ${latency?.toStringAsFixed(0)}ms, '
        'bandwidth: ${bandwidth?.toStringAsFixed(0)}kbps)';
  }
}

/// Monitors network quality during calls
///
/// Tracks connection metrics and provides quality assessments.
class NetworkQualityMonitor extends ChangeNotifier {
  final Duration sampleInterval;

  NetworkMetrics? _currentMetrics;
  final List<NetworkMetrics> _history = [];
  final int _maxHistorySize;

  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  NetworkQualityMonitor({
    this.sampleInterval = const Duration(seconds: 2),
    int maxHistorySize = 30, // Keep last 30 samples (1 minute at 2s interval)
  }) : _maxHistorySize = maxHistorySize;

  /// Current network metrics
  NetworkMetrics? get currentMetrics => _currentMetrics;

  /// Current network quality
  NetworkQuality get quality =>
      _currentMetrics?.quality ?? NetworkQuality.disconnected;

  /// Is currently monitoring
  bool get isMonitoring => _isMonitoring;

  /// Metrics history
  List<NetworkMetrics> get history => List.unmodifiable(_history);

  /// Start monitoring network quality
  void startMonitoring({Future<NetworkMetrics> Function()? metricsProvider}) {
    if (_isMonitoring) {
      return;
    }

    _isMonitoring = true;

    _monitoringTimer = Timer.periodic(sampleInterval, (timer) async {
      try {
        // Get metrics from provider or use simulated metrics
        final metrics = metricsProvider != null
            ? await metricsProvider()
            : _simulateMetrics();

        _updateMetrics(metrics);
      } catch (e) {
        sl<AppLogger>().error('Error collecting metrics', tag: 'NetworkMonitor', error: e);
      }
    });

    sl<AppLogger>().debug('Started monitoring', tag: 'NetworkMonitor');
  }

  /// Stop monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;

    sl<AppLogger>().debug('Stopped monitoring', tag: 'NetworkMonitor');
  }

  /// Update metrics and notify listeners
  void _updateMetrics(NetworkMetrics metrics) {
    final previousQuality = _currentMetrics?.quality;
    _currentMetrics = metrics;

    // Add to history
    _history.add(metrics);
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
    }

    // Notify if quality changed
    if (previousQuality != metrics.quality) {
      sl<AppLogger>().debug(
        'Quality changed: ${previousQuality?.label} → ${metrics.quality.label}',
        tag: 'NetworkMonitor',
      );
      notifyListeners();
    }
  }

  /// Manually update metrics (for external integration)
  void updateMetrics({
    double? packetLoss,
    double? jitter,
    double? latency,
    double? bandwidth,
  }) {
    final metrics = NetworkMetrics(
      packetLoss: packetLoss,
      jitter: jitter,
      latency: latency,
      bandwidth: bandwidth,
    );

    _updateMetrics(metrics);
  }

  /// Get average metrics over history
  NetworkMetrics? getAverageMetrics() {
    if (_history.isEmpty) {
      return null;
    }

    double? avgPacketLoss;
    double? avgJitter;
    double? avgLatency;
    double? avgBandwidth;

    final validPacketLoss = _history
        .where((m) => m.packetLoss != null)
        .toList();
    if (validPacketLoss.isNotEmpty) {
      avgPacketLoss =
          validPacketLoss.map((m) => m.packetLoss!).reduce((a, b) => a + b) /
          validPacketLoss.length;
    }

    final validJitter = _history.where((m) => m.jitter != null).toList();
    if (validJitter.isNotEmpty) {
      avgJitter =
          validJitter.map((m) => m.jitter!).reduce((a, b) => a + b) /
          validJitter.length;
    }

    final validLatency = _history.where((m) => m.latency != null).toList();
    if (validLatency.isNotEmpty) {
      avgLatency =
          validLatency.map((m) => m.latency!).reduce((a, b) => a + b) /
          validLatency.length;
    }

    final validBandwidth = _history.where((m) => m.bandwidth != null).toList();
    if (validBandwidth.isNotEmpty) {
      avgBandwidth =
          validBandwidth.map((m) => m.bandwidth!).reduce((a, b) => a + b) /
          validBandwidth.length;
    }

    return NetworkMetrics(
      packetLoss: avgPacketLoss,
      jitter: avgJitter,
      latency: avgLatency,
      bandwidth: avgBandwidth,
    );
  }

  /// Check if connection is stable
  bool get isStable {
    if (_history.length < 3) {
      return true; // Not enough data
    }

    final recentMetrics = _history.skip(_history.length - 3);
    return recentMetrics.every(
      (m) =>
          m.quality == NetworkQuality.excellent ||
          m.quality == NetworkQuality.good,
    );
  }

  /// Clear history
  void clearHistory() {
    _history.clear();
    _currentMetrics = null;
    notifyListeners();
  }

  /// Simulate metrics for testing/demo
  NetworkMetrics _simulateMetrics() {
    // Simulate realistic metrics with some variance
    final random = DateTime.now().millisecondsSinceEpoch % 100;

    return NetworkMetrics(
      packetLoss: 0.5 + (random / 100),
      jitter: 10 + (random / 5),
      latency: 50 + random.toDouble(),
      bandwidth: 1000 + random * 10,
    );
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
