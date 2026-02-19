import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/shared/themes/app_spacing.dart';
import 'package:greenhive_app/shared/services/media_cache_service.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-screen PDF viewer page with navigation, zoom, and search.
///
/// Supports loading PDFs from:
/// - Remote URL (will be cached)
/// - Local file
class PDFViewerPage extends StatefulWidget {
  final String? url;
  final File? localFile;
  final String fileName;
  final String? roomId;

  const PDFViewerPage({
    super.key,
    this.url,
    this.localFile,
    required this.fileName,
    this.roomId,
  }) : assert(url != null || localFile != null, 'Either url or localFile must be provided');

  @override
  State<PDFViewerPage> createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  late final PdfViewerController _pdfController;
  final TextEditingController _searchController = TextEditingController();
  final AppLogger _logger = sl<AppLogger>();

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  File? _cachedFile;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _showSearchBar = false;
  PdfTextSearchResult? _searchResult;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    // On web, callers should use PDFViewerPageWeb instead
    if (kIsWeb) {
      _logger.error('PDF Viewer: This page should not be used on web. Use PDFViewerPageWeb instead.');
      setState(() {
        _hasError = true;
        _errorMessage = 'Use PDFViewerPageWeb for web platform';
        _isLoading = false;
      });
      return;
    }

    // Mobile/desktop: use file-based approach with caching
    if (widget.localFile != null) {
      setState(() {
        _cachedFile = widget.localFile;
        _isLoading = false;
      });
      return;
    }

    if (widget.url == null) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No PDF source provided';
        _isLoading = false;
      });
      return;
    }

    try {
      // Try to get from cache first using MediaCacheService
      final cacheService = sl<MediaCacheService>();
      final roomId = widget.roomId ?? 'documents';
      
      final fileInfo = await cacheService.getMediaFile(roomId, widget.url!);

      if (fileInfo != null && fileInfo.file.existsSync()) {
        if (mounted) {
          setState(() {
            _cachedFile = fileInfo.file;
            _isLoading = false;
          });
        }
        return;
      }

      // If getMediaFile returns null, show error
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to download PDF';
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      _logger.error('Failed to load PDF', error: e, stackTrace: stack);
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load PDF: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    setState(() {
      _totalPages = details.document.pages.count;
    });
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() {
      _currentPage = details.newPageNumber;
    });
  }

  void _toggleSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchController.clear();
        _searchResult?.clear();
      }
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      _searchResult?.clear();
      return;
    }
    _searchResult = _pdfController.searchText(query);
  }

  void _nextSearchResult() {
    _searchResult?.nextInstance();
  }

  void _previousSearchResult() {
    _searchResult?.previousInstance();
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      _pdfController.jumpToPage(page);
    }
  }

  void _showPageJumpDialog() {
    final pageController = TextEditingController(text: _currentPage.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Go to Page',
          style: AppTypography.headingSmall.copyWith(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: pageController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '1 - $_totalPages',
            hintStyle: AppTypography.bodyRegular.copyWith(color: AppColors.textMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          style: AppTypography.bodyRegular.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.button.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              final page = int.tryParse(pageController.text);
              if (page != null) {
                _goToPage(page);
              }
              Navigator.pop(context);
            },
            child: Text(
              'Go',
              style: AppTypography.button.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _openExternally() async {
    final file = _cachedFile ?? widget.localFile;
    if (file != null) {
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (widget.url != null) {
      final uri = Uri.parse(widget.url!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              style: AppTypography.headingSmall.copyWith(color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_totalPages > 0)
              Text(
                'Page $_currentPage of $_totalPages',
                style: AppTypography.captionSmall.copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showSearchBar ? Icons.search_off : Icons.search,
              color: AppColors.textPrimary,
            ),
            onPressed: _toggleSearch,
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, color: AppColors.textPrimary),
            onPressed: _openExternally,
            tooltip: 'Open externally',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onSelected: (value) {
              if (value == 'jump') {
                _showPageJumpDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'jump',
                child: Row(
                  children: [
                    const Icon(Icons.bookmark, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      'Go to page',
                      style: AppTypography.bodyRegular.copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          if (_showSearchBar)
            Container(
              padding: const EdgeInsets.all(AppSpacing.spacing8),
              color: AppColors.surface,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search in document...',
                        hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      ),
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                      onSubmitted: _performSearch,
                      onChanged: _performSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up, color: AppColors.textSecondary),
                    onPressed: _previousSearchResult,
                    tooltip: 'Previous',
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                    onPressed: _nextSearchResult,
                    tooltip: 'Next',
                  ),
                ],
              ),
            ),

          // PDF content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Loading PDF...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      _logger.error('PDF Viewer _buildContent: Displaying error state');
      _logger.error('PDF Viewer _buildContent: Error message = $_errorMessage');
      _logger.error('PDF Viewer _buildContent: URL was = ${widget.url}');
      
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load PDF',
                style: AppTypography.headingSmall.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 8),
                SelectableText(
                  'URL: ${widget.url ?? "null"}',
                  style: AppTypography.captionSmall.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _hasError = false;
                    _errorMessage = null;
                  });
                  _loadPdf();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // On mobile/desktop, use SfPdfViewer.file() with cached file
    final file = _cachedFile ?? widget.localFile;
    if (file == null) {
      return const Center(
        child: Text(
          'No PDF file available',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // Check file size for memory optimization decisions
    final fileSizeInMB = file.lengthSync() / (1024 * 1024);
    final isLargeFile = fileSizeInMB > 10; // Files > 10MB

    return SfPdfViewer.file(
      file,
      key: _pdfViewerKey,
      controller: _pdfController,
      onDocumentLoaded: _onDocumentLoaded,
      onPageChanged: _onPageChanged,
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        _logger.error('PDF load failed: ${details.error}');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Failed to load PDF: ${details.description}';
          });
        }
      },
      canShowScrollHead: true,
      canShowScrollStatus: true,
      enableDoubleTapZooming: true,
      // Disable text selection for large files to reduce memory
      enableTextSelection: !isLargeFile,
      pageSpacing: 4,
      // Limit zoom for large files to reduce memory usage
      maxZoomLevel: isLargeFile ? 2.0 : 4.0,
      // Use single page mode for very large files to prevent OOM crashes
      pageLayoutMode: isLargeFile ? PdfPageLayoutMode.single : PdfPageLayoutMode.continuous,
    );
  }
}