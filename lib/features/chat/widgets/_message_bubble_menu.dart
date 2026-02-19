import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';

/// Popup menu for message actions (reply, copy, edit, delete)
/// Extracted from MessageBubble for better testability
class MessageBubbleMenu extends StatelessWidget {
  final Message message;
  final bool fromMe;
  final bool isLastMessageFromUser;
  final VoidCallback? onReply;
  final VoidCallback? onCopy;
  final Function(Message, String)? onEdit;
  final VoidCallback? onDelete;
  final Widget messageContentWidget;

  const MessageBubbleMenu({
    super.key,
    required this.message,
    required this.fromMe,
    required this.isLastMessageFromUser,
    this.onReply,
    this.onCopy,
    this.onEdit,
    this.onDelete,
    required this.messageContentWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tappable blur background - dismisses on tap
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              color: AppColors.background.withValues(alpha: 0.3),
            ),
          ),
        ),
        // Centered dialog with message and menu
        Align(
          alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Message bubble in menu
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: fromMe
                        ? AppColors.messageBubble
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.background.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.60,
                  ),
                  child: messageContentWidget,
                ),
                const SizedBox(height: 12),
                // Menu
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.60,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.background.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildMenuItems(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    return [
      _buildMenuItem(
        icon: Icons.reply,
        label: 'Reply',
        onTap: () {
          Navigator.pop(context);
          onReply?.call();
        },
      ),
      Container(height: 1, color: AppColors.divider),
      _buildMenuItem(
        icon: Icons.copy,
        label: 'Copy',
        onTap: () {
          Navigator.pop(context);
          onCopy?.call();
        },
      ),
      if (fromMe) ...[
        Container(height: 1, color: AppColors.divider),
        if (message.type == MessageType.text && isLastMessageFromUser)
          _buildMenuItem(
            icon: Icons.edit,
            label: 'Edit',
            onTap: () {
              Navigator.pop(context);
              onEdit?.call(message, message.text);
            },
          ),
        if (message.type == MessageType.text && isLastMessageFromUser)
          Container(height: 1, color: AppColors.divider),
        _buildMenuItem(
          icon: Icons.delete,
          label: 'Delete',
          isDestructive: true,
          onTap: () {
            Navigator.pop(context);
            onDelete?.call();
          },
        ),
      ],
    ];
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTypography.messageText.copyWith(
                  color: isDestructive
                      ? AppColors.error
                      : AppColors.textPrimary,
                ),
              ),
              Icon(
                icon,
                size: 20,
                color: isDestructive
                    ? AppColors.error
                    : AppColors.textPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
