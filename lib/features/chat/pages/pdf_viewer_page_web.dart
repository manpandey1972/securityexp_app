// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';

/// Web-specific PDF viewer that uses an iframe with the browser's native PDF viewer.
class PDFViewerPageWeb extends StatefulWidget {
  final String url;
  final String fileName;

  const PDFViewerPageWeb({
    super.key,
    required this.url,
    required this.fileName,
  });

  @override
  State<PDFViewerPageWeb> createState() => _PDFViewerPageWebState();
}

class _PDFViewerPageWebState extends State<PDFViewerPageWeb> {
  final AppLogger _logger = sl<AppLogger>();
  late final String _viewType;
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-viewer-${widget.url.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
    _registerViewFactory();
  }

  void _registerViewFactory() {
    _logger.info('PDF Viewer Web: Registering view factory for ${widget.url}');
    
    // Register the view factory
    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = widget.url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'fullscreen';
        return iframe;
      },
    );
    
    _isRegistered = true;
    _logger.info('PDF Viewer Web: View factory registered successfully');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          widget.fileName,
          style: AppTypography.headingSmall.copyWith(color: AppColors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _isRegistered
          ? HtmlElementView(viewType: _viewType)
          : const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
    );
  }
}
