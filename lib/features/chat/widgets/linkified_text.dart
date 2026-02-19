import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:greenhive_app/shared/themes/app_theme_dark.dart';
import 'package:greenhive_app/core/logging/app_logger.dart';
import 'package:greenhive_app/core/service_locator.dart';

/// Widget that renders text with clickable URLs
class LinkifiedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool selectable;

  static const String _tag = 'LinkifiedText';
  final AppLogger _log = sl<AppLogger>();

  LinkifiedText(this.text, {super.key, this.style, this.selectable = true});

  @override
  Widget build(BuildContext context) {
    final spans = _parseTextWithLinks();

    if (selectable) {
      return SelectableText.rich(TextSpan(children: spans), style: style);
    } else {
      return Text.rich(TextSpan(children: spans), style: style);
    }
  }

  List<InlineSpan> _parseTextWithLinks() {
    final spans = <InlineSpan>[];
    final urlRegex = RegExp(
      r'https?://[^\s]+|www\.[^\s]+',
      caseSensitive: false,
    );

    int lastIndex = 0;
    final matches = urlRegex.allMatches(text);

    for (final match in matches) {
      // Add text before the URL
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(text: text.substring(lastIndex, match.start), style: style),
        );
      }

      // Add the URL as a link
      final url = text.substring(match.start, match.end);
      spans.add(
        TextSpan(
          text: url,
          style: (style ?? const TextStyle()).copyWith(
            color: AppColors.primary,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => _launchURL(url),
        ),
      );

      lastIndex = match.end;
    }

    // Add remaining text after last URL
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: style));
    }

    // If no URLs found, return the original text
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: style));
    }

    return spans;
  }

  Future<void> _launchURL(String url) async {
    try {
      var urlString = url;
      if (!urlString.startsWith('http://') &&
          !urlString.startsWith('https://')) {
        urlString = 'https://$urlString';
      }

      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _log.warning('Could not launch URL: $urlString', tag: _tag);
      }
    } catch (e) {
      _log.error('Error launching URL: $e', tag: _tag);
    }
  }
}
