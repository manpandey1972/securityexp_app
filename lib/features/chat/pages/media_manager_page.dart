import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/shared/themes/app_borders.dart';
import 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';
import 'package:securityexperts_app/features/home/constants/home_page_constants.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:securityexperts_app/shared/services/media_cache_service.dart';
import 'package:securityexperts_app/shared/themes/app_spacing.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';
import 'package:securityexperts_app/shared/themes/app_card_styles.dart';
import 'package:securityexperts_app/features/chat/widgets/cached_media_widgets.dart';
import 'package:securityexperts_app/features/chat/pages/pdf_viewer_page.dart';
import 'package:securityexperts_app/features/chat/pages/text_viewer_page.dart';

// Dedicated cached media page
class CachedMediaPage extends StatefulWidget {
  final String roomId;
  final MediaCacheService mediaCacheService;
  final Future<void> Function()? prefetch;

  const CachedMediaPage({
    super.key,
    required this.roomId,
    required this.mediaCacheService,
    this.prefetch,
  });

  @override
  State<CachedMediaPage> createState() => _CachedMediaPageState();
}

class _CachedMediaPageState extends State<CachedMediaPage> {
  late Future<List<FileInfo>> _future;
  int _selectedTabIndex = 0;
  bool _isGridView = true; // Toggle between grid and list view

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FileInfo>> _load() async {
    if (widget.prefetch != null) {
      await widget.prefetch!();
    }
    return widget.mediaCacheService.getAllCachedFiles(widget.roomId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  // Filter files by category
  List<FileInfo> _filterByCategory(List<FileInfo> files, String category) {
    switch (category) {
      case 'media':
        return files.where((f) => _isImage(f) || _isVideo(f)).toList();
      case 'audio':
        return files.where((f) => _isAudio(f)).toList();
      case 'docs':
        return files.where((f) => _isDocument(f)).toList();
      default:
        return files;
    }
  }

  Future<void> _downloadFile(FileInfo fileInfo) async {
    try {
      final ext = _getFileExtension(fileInfo);
      final isImage = _isImage(fileInfo);
      final isVideo = _isVideo(fileInfo);
      final isAudio = _isAudio(fileInfo);
      final isDocument = _isDocument(fileInfo);

      // Generate timestamp-based filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      String finalFileName;

      if (isImage || isVideo || isAudio) {
        finalFileName = 'media_$timestamp.$ext';
      } else if (isDocument) {
        finalFileName = 'document_$timestamp.$ext';
      } else {
        finalFileName = 'file_$timestamp.$ext';
      }

      // For iOS, save all files to Documents directory (accessible via Files app)
      if (Platform.isIOS) {
        Directory docsDir = await getApplicationDocumentsDirectory();

        if (!docsDir.existsSync()) {
          docsDir.createSync(recursive: true);
        }

        var finalPath = '${docsDir.path}/$finalFileName';

        await fileInfo.file.copy(finalPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved to Files app: $finalFileName')),
          );
        }
        return;
      }

      // For Android and other platforms
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Downloads directory not available')),
          );
        }
        return;
      }

      // Ensure downloads directory exists
      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }

      final finalPath = '${downloadsDir.path}/$finalFileName';

      await fileInfo.file.copy(finalPath);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Downloaded to: $finalPath')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  void _openPreview(FileInfo fileInfo) async {
    if (_isImage(fileInfo)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Image')),
            body: Center(
              child: InteractiveViewer(
                child: Image.file(fileInfo.file, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
      return;
    }

    if (_isVideo(fileInfo)) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CachedVideoPlayerPage(file: fileInfo.file),
        ),
      );
      return;
    }

    // Handle documents (PDF and text files) with in-app viewer
    if (_isPdf(fileInfo)) {
      if (!mounted) return;
      if (kIsWeb) {
        // On web, open file externally
        final uri = Uri.file(fileInfo.file.path);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        // On mobile/desktop, use in-app viewer
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PDFViewerPage(
              localFile: fileInfo.file,
              fileName: _getFileName(fileInfo),
              roomId: widget.roomId,
            ),
          ),
        );
      }
      return;
    }

    if (_isTextFile(fileInfo)) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TextViewerPage(
            localFile: fileInfo.file,
            fileName: _getFileName(fileInfo),
            roomId: widget.roomId,
          ),
        ),
      );
      return;
    }

    // Fallback to system viewer for other file types
    launchUrl(Uri.file(fileInfo.file.path), mode: LaunchMode.platformDefault);
  }

  bool _isImage(FileInfo fileInfo) {
    var source =
        (fileInfo.originalUrl.isNotEmpty
                ? fileInfo.originalUrl
                : fileInfo.file.path)
            .toLowerCase();
    // Remove query parameters for extension detection
    source = source.split('?').first;
    final isImg =
        source.endsWith('.jpg') ||
        source.endsWith('.jpeg') ||
        source.endsWith('.png') ||
        source.endsWith('.gif') ||
        source.endsWith('.webp') ||
        source.endsWith('.bmp');
    return isImg;
  }

  bool _isVideo(FileInfo fileInfo) {
    var source =
        (fileInfo.originalUrl.isNotEmpty
                ? fileInfo.originalUrl
                : fileInfo.file.path)
            .toLowerCase();
    // Remove query parameters for extension detection
    source = source.split('?').first;
    final isVid =
        source.endsWith('.mp4') ||
        source.endsWith('.mov') ||
        source.endsWith('.avi') ||
        source.endsWith('.mkv') ||
        source.endsWith('.webm');
    return isVid;
  }

  bool _isAudio(FileInfo fileInfo) {
    var source =
        (fileInfo.originalUrl.isNotEmpty
                ? fileInfo.originalUrl
                : fileInfo.file.path)
            .toLowerCase();
    source = source.split('?').first;
    return source.endsWith('.mp3') ||
        source.endsWith('.wav') ||
        source.endsWith('.m4a') ||
        source.endsWith('.aac') ||
        source.endsWith('.flac') ||
        source.endsWith('.ogg');
  }

  bool _isDocument(FileInfo fileInfo) {
    var source =
        (fileInfo.originalUrl.isNotEmpty
                ? fileInfo.originalUrl
                : fileInfo.file.path)
            .toLowerCase();
    source = source.split('?').first;
    return source.endsWith('.pdf') ||
        source.endsWith('.doc') ||
        source.endsWith('.docx') ||
        source.endsWith('.txt') ||
        source.endsWith('.xlsx') ||
        source.endsWith('.xls') ||
        source.endsWith('.ppt') ||
        source.endsWith('.pptx');
  }

  bool _isPdf(FileInfo fileInfo) {
    var source =
        (fileInfo.originalUrl.isNotEmpty
                ? fileInfo.originalUrl
                : fileInfo.file.path)
            .toLowerCase();
    source = source.split('?').first;
    return source.endsWith('.pdf');
  }

  bool _isTextFile(FileInfo fileInfo) {
    var source =
        (fileInfo.originalUrl.isNotEmpty
                ? fileInfo.originalUrl
                : fileInfo.file.path)
            .toLowerCase();
    source = source.split('?').first;
    const textExtensions = [
      '.txt', '.md', '.log', '.dart', '.js', '.ts', '.json',
      '.xml', '.yaml', '.yml', '.html', '.css', '.py', '.java',
      '.kt', '.swift', '.c', '.cpp', '.h', '.hpp', '.sh', '.bash',
      '.zsh', '.env', '.ini', '.cfg', '.conf', '.toml', '.gradle',
    ];
    for (final ext in textExtensions) {
      if (source.endsWith(ext)) return true;
    }
    return false;
  }

  String _getFileExtension(FileInfo fileInfo) {
    var source =
        (fileInfo.originalUrl.isNotEmpty
                ? fileInfo.originalUrl
                : fileInfo.file.path)
            .toLowerCase();
    source = source.split('?').first;
    final parts = source.split('.');
    return parts.isNotEmpty ? parts.last : 'file';
  }

  String _getFileName(FileInfo fileInfo) {
    // Use originalUrl if available, otherwise use file path
    var source = fileInfo.originalUrl.isNotEmpty
        ? fileInfo.originalUrl
        : fileInfo.file.path;

    // URL decode to handle %2F and other encoded characters
    source = Uri.decodeFull(source);

    // Remove query parameters
    source = source.split('?').first;

    // Extract just the filename (everything after the last /)
    var fileName = source.split('/').last;

    // If filename starts with timestamp (all digits), remove it
    // Format: "1733686523456_actualFileName.ext"
    if (fileName.contains('_')) {
      final firstPart = fileName.split('_')[0];
      // Check if first part is all digits (timestamp)
      if (firstPart.replaceAll(RegExp(r'[0-9]'), '').isEmpty) {
        // Remove timestamp and leading underscore
        fileName = fileName.substring(firstPart.length + 1);
      }
    }

    // Fallback: generate a friendly name based on file type
    if (fileName.isEmpty || fileName.startsWith('chat_attachments')) {
      if (_isImage(fileInfo)) {
        return 'Image';
      } else if (_isVideo(fileInfo)) {
        return 'Video';
      } else if (_isAudio(fileInfo)) {
        return 'Audio';
      } else if (_isDocument(fileInfo)) {
        return 'Document';
      }
      return 'File';
    }

    return fileName;
  }

  IconData _getFileIcon(FileInfo fileInfo) {
    if (_isAudio(fileInfo)) return Icons.music_note;
    if (_isDocument(fileInfo)) {
      final ext = _getFileExtension(fileInfo);
      if (ext.contains('pdf')) return Icons.picture_as_pdf;
      if (ext.contains('doc')) return Icons.description;
      if (ext.contains('sheet') || ext.contains('xls')) {
        return Icons.table_chart;
      }
      return Icons.insert_drive_file;
    }
    return Icons.insert_drive_file;
  }

  Widget _thumbnail(FileInfo fileInfo) {
    if (_isImage(fileInfo)) {
      return ClipRRect(
        borderRadius: AppBorders.borderRadiusNormal,
        child: Image.file(
          fileInfo.file,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image),
        ),
      );
    }

    if (_isVideo(fileInfo)) {
      return FutureBuilder<Uint8List?>(
        future: video_thumbnail.VideoThumbnail.thumbnailData(
          video: fileInfo.file.path,
          imageFormat: video_thumbnail.ImageFormat.PNG,
          maxWidth: 240,
          quality: 75,
        ),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes != null) {
            return ClipRRect(
              borderRadius: AppBorders.borderRadiusNormal,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Image.memory(bytes, fit: BoxFit.cover),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.26),
                      borderRadius: AppBorders.borderRadiusNormal,
                    ),
                    child: const Icon(
                      Icons.play_circle_fill,
                      color: AppColors.textSecondary,
                      size: 36,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          return Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppBorders.borderRadiusNormal,
            ),
            child: const Icon(
              Icons.play_circle_outline,
              color: AppColors.white,
            ),
          );
        },
      );
    }

    if (_isAudio(fileInfo)) {
      return InlineAudioThumbnail(file: fileInfo.file, fileInfo: fileInfo);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppBorders.borderRadiusNormal,
      ),
      child: Center(
        child: Icon(
          _getFileIcon(fileInfo),
          color: AppColors.white,
          size: AppIconSizes.xlarge,
        ),
      ),
    );
  }

  Widget _buildNavTab(int index, IconData icon, String label) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: SizedBox(
        width: HomePageConstants.bottomNavItemWidth,
        height: HomePageConstants.bottomNavItemHeight,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HomePageConstants.bottomNavItemPaddingHorizontal,
            vertical: HomePageConstants.bottomNavItemPaddingVertical,
          ),
          decoration: BoxDecoration(
            border: isSelected
                ? Border(
                    top: BorderSide(
                      color: AppColors.primary,
                      width: HomePageConstants.bottomNavTopBorderWidth,
                    ),
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(
                height: HomePageConstants.bottomNavIconLabelSpacing,
              ),
              Text(
                label,
                style: AppTypography.captionSmall.copyWith(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: isSelected
                      ? AppTypography.semiBold
                      : AppTypography.regular,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showClearCacheDialog() async {
    final cacheSize = await widget.mediaCacheService.getCacheSizeBytes(
      widget.roomId,
    );
    final binFileCount = await widget.mediaCacheService.getBinFileCount(
      widget.roomId,
    );
    final formattedSize = widget.mediaCacheService.formatCacheSize(cacheSize);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Media Cache'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current cache size: $formattedSize'),
            if (binFileCount > 0) ...[
              SizedBox(height: AppSpacing.spacing8),
              Text(
                '$binFileCount legacy .bin files found',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.warning,
                ),
              ),
              SizedBox(height: AppSpacing.spacing4),
              Text(
                'These files may cause playback issues.',
                style: AppTypography.captionSmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
            SizedBox(height: AppSpacing.spacing16),
            const Text('Choose an action:'),
          ],
        ),
        actions: [
          AppButtonVariants.dialogCancel(
            onPressed: () => Navigator.of(context).pop(),
          ),
          if (binFileCount > 0)
            AppButtonVariants.dialogAction(
              onPressed: () async {
                Navigator.of(context).pop();
                final count = await widget.mediaCacheService
                    .clearLegacyBinFiles(widget.roomId);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Cleared $count legacy files')),
                  );
                  _refresh();
                }
              },
              label: 'Clear .bin Files Only',
            ),
          AppButtonVariants.dialogAction(
            onPressed: () async {
              Navigator.of(context).pop();
              await widget.mediaCacheService.clearCache(widget.roomId);
              if (mounted) {
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
                _refresh();
              }
            },
            label: 'Clear All Cache',
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Manager'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? 'List View' : 'Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear Cache',
            onPressed: _showClearCacheDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<FileInfo>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final files = snapshot.data ?? [];

            return Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _getMediaTabContent(context, files, _selectedTabIndex),
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: const Border(
            top: BorderSide(
              color: AppColors.divider,
              width: HomePageConstants.bottomNavBorderWidth,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavTab(0, Icons.image, 'Photos'),
            _buildNavTab(1, Icons.audio_file, 'Audio'),
            _buildNavTab(2, Icons.description, 'Docs'),
          ],
        ),
      ),
    );
  }

  Widget _getMediaTabContent(
    BuildContext context,
    List<FileInfo> files,
    int tabIndex,
  ) {
    final categories = ['media', 'audio', 'docs'];
    final category = categories[tabIndex];
    return _buildMediaTab(context, files, category);
  }

  Widget _buildMediaTab(
    BuildContext context,
    List<FileInfo> files,
    String category,
  ) {
    final filteredFiles = _filterByCategory(files, category);

    if (filteredFiles.isEmpty) {
      return Center(
        child: Text(
          category == 'media'
              ? 'No photos'
              : category == 'audio'
              ? 'No audio files'
              : 'No documents',
        ),
      );
    }

    // Use ListView for docs always, or when list view is selected
    if (category == 'docs' || !_isGridView) {
      return ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: filteredFiles.length,
        itemBuilder: (context, index) {
          final fileInfo = filteredFiles[index];
          return _buildListItem(
            context,
            fileInfo,
            key: ValueKey(fileInfo.originalUrl),
          );
        },
      );
    }

    // GridView for photos, videos, and audio
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75, // Taller to accommodate file name
      ),
      itemCount: filteredFiles.length,
      itemBuilder: (context, index) {
        final fileInfo = filteredFiles[index];
        return _buildThumbnailWithName(
          context,
          fileInfo,
          key: ValueKey(fileInfo.originalUrl),
        );
      },
    );
  }

  Widget _buildThumbnailWithName(
    BuildContext context,
    FileInfo fileInfo, {
    Key? key,
  }) {
    return GestureDetector(
      key: key,
      onTap: () {
        _openPreview(fileInfo);
      },
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _thumbnail(fileInfo)),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(
                      Icons.download,
                      color: AppColors.white,
                      size: 18,
                    ),
                    padding: const EdgeInsets.all(0),
                    constraints: const BoxConstraints(),
                    onPressed: () => _downloadFile(fileInfo),
                    tooltip: 'Download',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.spacing4),
          Text(
            _getFileName(fileInfo),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.captionTiny.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(BuildContext context, FileInfo fileInfo, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: AppCardStyle.filled,
        child: Stack(
          children: [
            ListTile(
              leading: Icon(
                _getFileIcon(fileInfo),
                color: AppColors.white,
                size: 32,
              ),
              title: Text(
                _getFileName(fileInfo),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyEmphasis,
              ),
              subtitle: Text(
                _getFileExtension(fileInfo).toUpperCase(),
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () {
                _openPreview(fileInfo);
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.download, color: AppColors.white),
                onPressed: () => _downloadFile(fileInfo),
                tooltip: 'Download',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
