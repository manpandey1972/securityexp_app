import 'dart:io';

import 'package:flutter/material.dart';
import 'package:greenhive_app/features/support/data/models/models.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:path/path.dart' as path;

/// Input widget for composing messages in ticket detail.
///
/// Includes text field, attachment preview, and send button.
class MessageInput extends StatefulWidget {
  /// Current text value.
  final String text;

  /// Callback when text changes.
  final ValueChanged<String> onTextChanged;

  /// List of attachments.
  final List<PendingAttachment> attachments;

  /// Callback to add image.
  final VoidCallback onAddImage;

  /// Callback to add file.
  final VoidCallback onAddFile;

  /// Callback to remove attachment.
  final ValueChanged<int> onRemoveAttachment;

  /// Callback when send is pressed.
  final VoidCallback onSend;

  /// Whether message can be sent.
  final bool canSend;

  /// Whether sending is in progress.
  final bool isSending;

  /// Whether input is enabled.
  final bool enabled;

  const MessageInput({
    super.key,
    required this.text,
    required this.onTextChanged,
    required this.attachments,
    required this.onAddImage,
    required this.onAddFile,
    required this.onRemoveAttachment,
    required this.onSend,
    required this.canSend,
    this.isSending = false,
    this.enabled = true,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(MessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _controller.text) {
      _controller.text = widget.text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Attachment preview
            if (widget.attachments.isNotEmpty) _buildAttachmentPreview(),

            // Input row
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attachment buttons
                  _buildAttachmentButtons(),

                  const SizedBox(width: 8),

                  // Text input
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _controller,
                        enabled: widget.enabled,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: widget.enabled
                              ? 'Type your message...'
                              : 'This ticket is closed',
                          hintStyle: AppTypography.bodyRegular.copyWith(
                            color: AppColors.textMuted,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        style: AppTypography.bodyRegular,
                        onChanged: widget.onTextChanged,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Send button
                  _buildSendButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    return Container(
      height: 80,
      padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final attachment = widget.attachments[index];
          final extension = path.extension(attachment.filename).toLowerCase();
          final isImage = [
            '.jpg',
            '.jpeg',
            '.png',
            '.gif',
            '.webp',
          ].contains(extension);

          return Stack(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: isImage && attachment.bytes != null
                    ? Image.memory(attachment.bytes!, fit: BoxFit.cover)
                    : isImage && attachment.filePath != null
                        ? Image.file(File(attachment.filePath!), fit: BoxFit.cover)
                        : Center(
                            child: Icon(
                              extension == '.pdf'
                                  ? Icons.picture_as_pdf
                                  : Icons.insert_drive_file,
                              color: extension == '.pdf'
                                  ? AppColors.filePdf
                                  : AppColors.textMuted,
                            ),
                          ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: () => widget.onRemoveAttachment(index),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAttachmentButtons() {
    if (!widget.enabled || widget.attachments.length >= 5) {
      return const SizedBox(width: 48);
    }

    return IconButton(
      onPressed: _showAttachmentMenu,
      icon: const Icon(Icons.add),
      iconSize: 28,
      tooltip: 'Attach',
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primaryLight),
                title: Text('Photo', style: AppTypography.bodyRegular),
                onTap: () {
                  Navigator.pop(context);
                  widget.onAddImage();
                },
              ),
              ListTile(
                leading: Icon(Icons.attach_file, color: AppColors.primaryLight),
                title: Text('File', style: AppTypography.bodyRegular),
                onTap: () {
                  Navigator.pop(context);
                  widget.onAddFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    if (widget.isSending) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
            ),
          ),
        ),
      );
    }

    return IconButton(
      icon: Icon(
        Icons.send,
        color: widget.canSend ? AppColors.primaryLight : AppColors.textMuted,
      ),
      iconSize: 28,
      onPressed: widget.canSend ? widget.onSend : null,
      tooltip: 'Send',
    );
  }
}
