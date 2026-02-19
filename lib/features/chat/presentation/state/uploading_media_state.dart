import 'package:greenhive_app/data/models/models.dart';

/// Represents the state of a single uploading media item.
///
/// Consolidates the three separate maps (uploadingMessages, uploadingMessageFiles,
/// uploadingMessageTypes) into a single cohesive class for better encapsulation.
class UploadingMediaState {
  /// Temporary ID used to track this upload
  final String tempId;

  /// Upload progress (0.0 to 1.0)
  final double progress;

  /// Original filename
  final String filename;

  /// Type of media being uploaded
  final MessageType type;

  const UploadingMediaState({
    required this.tempId,
    required this.progress,
    required this.filename,
    required this.type,
  });

  /// Create a copy with updated progress
  UploadingMediaState copyWith({double? progress}) {
    return UploadingMediaState(
      tempId: tempId,
      progress: progress ?? this.progress,
      filename: filename,
      type: type,
    );
  }

  @override
  String toString() =>
      'UploadingMediaState(tempId: $tempId, progress: ${(progress * 100).toStringAsFixed(0)}%, file: $filename, type: $type)';
}

/// Extension to convert between the old map-based format and the new class-based format.
/// Provides backward compatibility during migration.
extension UploadingMediaStateExtensions on List<UploadingMediaState> {
  /// Convert to the legacy map format for backward compatibility
  Map<String, double> toProgressMap() {
    return {for (var item in this) item.tempId: item.progress};
  }

  /// Convert to the legacy filenames map format
  Map<String, String> toFilenamesMap() {
    return {for (var item in this) item.tempId: item.filename};
  }

  /// Convert to the legacy types map format
  Map<String, MessageType> toTypesMap() {
    return {for (var item in this) item.tempId: item.type};
  }

  /// Create from legacy map format
  static List<UploadingMediaState> fromMaps({
    required Map<String, double> progressMap,
    required Map<String, String> filenamesMap,
    required Map<String, MessageType> typesMap,
  }) {
    return progressMap.entries.map((entry) {
      return UploadingMediaState(
        tempId: entry.key,
        progress: entry.value,
        filename: filenamesMap[entry.key] ?? 'Unknown',
        type: typesMap[entry.key] ?? MessageType.doc,
      );
    }).toList();
  }
}
