import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/shared/themes/app_spacing.dart';
import 'package:greenhive_app/shared/services/media_cache_service.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

/// Full-screen text/code file viewer with syntax highlighting support.
///
/// Supports loading text files from:
/// - Remote URL (will be cached)
/// - Local file
class TextViewerPage extends StatefulWidget {
  final String? url;
  final File? localFile;
  final String fileName;
  final String? roomId;

  const TextViewerPage({
    super.key,
    this.url,
    this.localFile,
    required this.fileName,
    this.roomId,
  }) : assert(url != null || localFile != null, 'Either url or localFile must be provided');

  @override
  State<TextViewerPage> createState() => _TextViewerPageState();
}

class _TextViewerPageState extends State<TextViewerPage> {
  final AppLogger _logger = sl<AppLogger>();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String _content = '';
  double _fontSize = 14.0;
  bool _showLineNumbers = true;
  bool _wordWrap = true;
  bool _showSearchBar = false;
  List<int> _searchMatches = [];
  int _currentMatchIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    // Handle local file (mobile/desktop only)
    if (!kIsWeb && widget.localFile != null) {
      try {
        final content = await widget.localFile!.readAsString();
        setState(() {
          _content = content;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to read file: $e';
          _isLoading = false;
        });
      }
      return;
    }

    if (widget.url == null) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No file source provided';
        _isLoading = false;
      });
      return;
    }

    try {
      // On web, directly fetch via HTTP (no file caching)
      if (kIsWeb) {
        final response = await http.get(Uri.parse(widget.url!));
        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              _content = response.body;
              _isLoading = false;
            });
          }
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
        return;
      }

      // On mobile/desktop, try to get from cache first using MediaCacheService
      final cacheService = sl<MediaCacheService>();
      final roomId = widget.roomId ?? 'documents';
      
      final fileInfo = await cacheService.getMediaFile(roomId, widget.url!);

      if (fileInfo != null && fileInfo.file.existsSync()) {
        final content = await fileInfo.file.readAsString();
        if (mounted) {
          setState(() {
            _content = content;
            _isLoading = false;
          });
        }
        return;
      }

      // If cache service returns null, try direct HTTP download
      final response = await http.get(Uri.parse(widget.url!));
      if (response.statusCode == 200) {
        final content = response.body;

        if (mounted) {
          setState(() {
            _content = content;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e, stack) {
      _logger.error('Failed to load text file', error: e, stackTrace: stack);
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load file: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchController.clear();
        _searchMatches.clear();
        _currentMatchIndex = -1;
      }
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchMatches.clear();
        _currentMatchIndex = -1;
      });
      return;
    }

    final matches = <int>[];
    final lowerContent = _content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    
    int index = 0;
    while (true) {
      index = lowerContent.indexOf(lowerQuery, index);
      if (index == -1) break;
      matches.add(index);
      index += query.length;
    }

    setState(() {
      _searchMatches = matches;
      _currentMatchIndex = matches.isNotEmpty ? 0 : -1;
    });
  }

  void _nextSearchResult() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    });
  }

  void _previousSearchResult() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _searchMatches.length) % _searchMatches.length;
    });
  }

  void _increaseFontSize() {
    setState(() {
      _fontSize = (_fontSize + 2).clamp(10.0, 32.0);
    });
  }

  void _decreaseFontSize() {
    setState(() {
      _fontSize = (_fontSize - 2).clamp(10.0, 32.0);
    });
  }

  void _copyContent() {
    Clipboard.setData(ClipboardData(text: _content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Content copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openExternally() async {
    if (widget.localFile != null) {
      final uri = Uri.file(widget.localFile!.path);
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

  String _getLanguage() {
    final extension = widget.fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'dart':
        return 'Dart';
      case 'js':
        return 'JavaScript';
      case 'ts':
        return 'TypeScript';
      case 'json':
        return 'JSON';
      case 'xml':
        return 'XML';
      case 'yaml':
      case 'yml':
        return 'YAML';
      case 'html':
        return 'HTML';
      case 'css':
        return 'CSS';
      case 'md':
        return 'Markdown';
      case 'txt':
        return 'Plain Text';
      case 'log':
        return 'Log';
      default:
        return 'Text';
    }
  }

  Color _getSyntaxColor(String language) {
    switch (language) {
      case 'Dart':
        return Colors.blue;
      case 'JavaScript':
      case 'TypeScript':
        return Colors.yellow;
      case 'JSON':
        return Colors.orange;
      case 'XML':
      case 'HTML':
        return Colors.red;
      case 'YAML':
        return Colors.purple;
      case 'CSS':
        return Colors.pink;
      case 'Markdown':
        return Colors.teal;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = _getLanguage();
    final lineCount = _content.isEmpty ? 0 : _content.split('\n').length;

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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getSyntaxColor(language).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    language,
                    style: AppTypography.captionTiny.copyWith(
                      color: _getSyntaxColor(language),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$lineCount lines',
                  style: AppTypography.captionSmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
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
            icon: const Icon(Icons.copy, color: AppColors.textPrimary),
            onPressed: _copyContent,
            tooltip: 'Copy all',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onSelected: (value) {
              switch (value) {
                case 'font_up':
                  _increaseFontSize();
                  break;
                case 'font_down':
                  _decreaseFontSize();
                  break;
                case 'line_numbers':
                  setState(() => _showLineNumbers = !_showLineNumbers);
                  break;
                case 'word_wrap':
                  setState(() => _wordWrap = !_wordWrap);
                  break;
                case 'open_external':
                  _openExternally();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'font_up',
                child: Row(
                  children: [
                    const Icon(Icons.text_increase, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      'Increase font size',
                      style: AppTypography.bodyRegular.copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'font_down',
                child: Row(
                  children: [
                    const Icon(Icons.text_decrease, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      'Decrease font size',
                      style: AppTypography.bodyRegular.copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'line_numbers',
                child: Row(
                  children: [
                    Icon(
                      _showLineNumbers ? Icons.check_box : Icons.check_box_outline_blank,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Line numbers',
                      style: AppTypography.bodyRegular.copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'word_wrap',
                child: Row(
                  children: [
                    Icon(
                      _wordWrap ? Icons.check_box : Icons.check_box_outline_blank,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Word wrap',
                      style: AppTypography.bodyRegular.copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'open_external',
                child: Row(
                  children: [
                    const Icon(Icons.open_in_new, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      'Open externally',
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
                        hintText: 'Search in file...',
                        hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                        suffixText: _searchMatches.isNotEmpty
                            ? '${_currentMatchIndex + 1}/${_searchMatches.length}'
                            : null,
                        suffixStyle: AppTypography.captionSmall.copyWith(color: AppColors.textSecondary),
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

          // Text content
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
              'Loading file...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
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
                'Failed to load file',
                style: AppTypography.headingSmall.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _hasError = false;
                    _errorMessage = null;
                  });
                  _loadContent();
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

    if (_content.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.description_outlined,
              color: AppColors.textSecondary,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'File is empty',
              style: AppTypography.headingSmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final lines = _content.split('\n');
    final lineNumberWidth = lines.length.toString().length * 10.0 + 16.0;

    return Container(
      color: const Color(0xFF1E1E1E), // Dark code editor background
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line numbers column (fixed width, scrolls with content)
          if (_showLineNumbers)
            Container(
              width: lineNumberWidth,
              color: const Color(0xFF252526),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(
                    lines.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: _fontSize,
                          color: const Color(0xFF858585),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Code content (fills remaining width, text wraps)
          Expanded(
            child: SingleChildScrollView(
              controller: _showLineNumbers ? null : _scrollController,
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _content,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: _fontSize,
                  color: const Color(0xFFD4D4D4),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
