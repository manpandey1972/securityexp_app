import 'package:flutter/material.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/shared/widgets/error_state_widget.dart';
import 'package:intl/intl.dart';

import '../data/models/models.dart';
import '../services/support_service.dart';
import '../presentation/view_models/ticket_detail_view_model.dart';
import '../presentation/state/ticket_detail_state.dart';
import '../widgets/ticket_status_chip.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/satisfaction_rating_dialog.dart';

/// Page displaying ticket details and conversation.
class TicketDetailPage extends StatefulWidget {
  final String ticketId;

  const TicketDetailPage({super.key, required this.ticketId});

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  late final TicketDetailViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = TicketDetailViewModel(
      supportService: sl<SupportService>(),
      ticketId: widget.ticketId,
    );
    _viewModel.initialize();
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    // Scroll to bottom when new messages arrive
    if (_viewModel.state.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final state = _viewModel.state;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(state),
          body: state.isLoading
              ? _buildLoading()
              : state.error != null && state.ticket == null
              ? _buildError(state.error!)
              : _buildContent(state),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(TicketDetailState state) {
    final ticket = state.ticket;

    return AppBar(
      backgroundColor: AppColors.surface,
      title: Text(
        ticket != null
            ? (ticket.ticketNumber.isNotEmpty
                  ? '#${ticket.ticketNumber}'
                  : '#${ticket.id.substring(0, 8).toUpperCase()}')
            : 'Loading...',
        style: AppTypography.bodyRegular.copyWith(fontWeight: FontWeight.w600),
      ),
      actions: [
        if (ticket != null && state.canRate)
          IconButton(
            icon: const Icon(Icons.star_outline),
            onPressed: _viewModel.showRatingDialog,
            tooltip: 'Rate experience',
          ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildError(String error) {
    return ErrorStateWidget(
      title: 'Something went wrong',
      message: error,
      onRetry: _viewModel.refresh,
    );
  }

  Widget _buildContent(TicketDetailState state) {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              // Ticket info header
              _buildTicketHeader(state.ticket!),

              // Rating prompt banner for resolved unrated tickets
              if (state.canRate) _buildRatingPromptBanner(),

              // Messages list
              Expanded(child: _buildMessagesList(state)),

              // Message input
              MessageInput(
                text: state.messageText,
                onTextChanged: _viewModel.setMessageText,
                attachments: state.messageAttachments,
                onAddImage: _viewModel.pickImage,
                onAddFile: _viewModel.pickFile,
                onRemoveAttachment: _viewModel.removeAttachment,
                onSend: _viewModel.sendMessage,
                canSend: state.canSendMessage,
                isSending: state.isSending,
                enabled: state.canReply,
              ),
            ],
          ),
        ),

        // Rating dialog
        if (state.showRatingDialog)
          SatisfactionRatingDialog(
            selectedRating: state.selectedRating,
            comment: state.ratingComment,
            onRatingChanged: _viewModel.setRating,
            onCommentChanged: _viewModel.setRatingComment,
            onSubmit: _viewModel.submitRating,
            onDismiss: _viewModel.hideRatingDialog,
            isSubmitting: state.isSubmittingRating,
          ),
      ],
    );
  }

  Widget _buildTicketHeader(SupportTicket ticket) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with subject and status at far right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject/Title
              Expanded(
                child: Text(
                  ticket.subject,
                  style: AppTypography.bodyEmphasis.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TicketStatusChip(status: ticket.status),
            ],
          ),



          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),

          // Details row - all in one row
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _DetailItem(
                icon: _getTypeIcon(ticket.type),
                label: 'Type',
                value: ticket.type.displayName,
                iconColor: _getTypeColor(ticket.type),
              ),
              _DetailItem(
                icon: Icons.category_outlined,
                label: 'Category',
                value: ticket.category.displayName,
              ),
              if (ticket.priority == TicketPriority.critical ||
                  ticket.priority == TicketPriority.high)
                _DetailItem(
                  icon: Icons.flag_outlined,
                  label: 'Priority',
                  value: ticket.priority.displayName,
                  iconColor: AppColors.error,
                ),
              _DetailItem(
                icon: Icons.calendar_today_outlined,
                label: 'Created',
                value: _formatRelativeDate(ticket.createdAt),
              ),
              _DetailItem(
                icon: Icons.update_outlined,
                label: 'Updated',
                value: _formatRelativeDate(ticket.lastActivityAt),
              ),
              if (ticket.userSatisfactionRating != null)
                _DetailItem(
                  icon: Icons.star,
                  label: 'Rating',
                  value: '${ticket.userSatisfactionRating}/5',
                  iconColor: AppColors.warning,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat.MMMd().format(date);
    }
  }

  Widget _buildMessagesList(TicketDetailState state) {
    final allItems = _buildMessageItems(state);

    if (allItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll respond to your ticket soon',
              style: AppTypography.captionSmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: allItems.length,
      itemBuilder: (context, index) => allItems[index],
    );
  }

  List<Widget> _buildMessageItems(TicketDetailState state) {
    final items = <Widget>[];
    final messages = state.messages;

    // Add initial ticket description as first "message"
    if (state.ticket != null) {
      items.add(_InitialTicketDescription(ticket: state.ticket!));
    }

    // Add messages
    DateTime? lastDate;
    for (final message in messages) {
      // Add date separator if needed
      final messageDate = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );
      if (lastDate == null || messageDate != lastDate) {
        items.add(_DateSeparator(date: messageDate));
        lastDate = messageDate;
      }

      items.add(
        MessageBubble(message: message, isCurrentUser: message.isFromUser),
      );
    }

    return items;
  }

  IconData _getTypeIcon(TicketType type) {
    switch (type) {
      case TicketType.bug:
        return Icons.bug_report;
      case TicketType.featureRequest:
        return Icons.lightbulb_outline;
      case TicketType.feedback:
        return Icons.feedback_outlined;
      case TicketType.support:
        return Icons.help_outline;
      case TicketType.account:
        return Icons.person_outline;
      case TicketType.payment:
        return Icons.payment;
    }
  }

  Color _getTypeColor(TicketType type) {
    switch (type) {
      case TicketType.bug:
        return AppColors.error;
      case TicketType.featureRequest:
        return AppColors.ratingStar;
      case TicketType.feedback:
        return AppColors.primary;
      case TicketType.support:
        return AppColors.info;
      case TicketType.account:
        return AppColors.purple;
      case TicketType.payment:
        return AppColors.teal;
    }
  }

  Widget _buildRatingPromptBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.star_outline, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How was your experience?',
                  style: AppTypography.bodyRegular.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your feedback helps us improve our support',
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _viewModel.showRatingDialog,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }
}

class _InitialTicketDescription extends StatefulWidget {
  final SupportTicket ticket;

  const _InitialTicketDescription({required this.ticket});

  @override
  State<_InitialTicketDescription> createState() => _InitialTicketDescriptionState();
}

class _InitialTicketDescriptionState extends State<_InitialTicketDescription> {
  bool _minimized = true;

  void _toggle() {
    setState(() {
      _minimized = !_minimized;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  _minimized ? Icons.expand_more : Icons.expand_less,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  'Description',
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _minimized ? 'Show' : 'Hide',
                  style: AppTypography.captionTiny.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!_minimized) ...[
            const SizedBox(height: 12),
            Text(
              widget.ticket.description,
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.ticket.attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              MessageAttachments(attachments: widget.ticket.attachments),
            ],
          ],
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (date == today) {
      label = 'Today';
    } else if (date == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat.MMMEd().format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: AppTypography.captionSmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor ?? AppColors.textMuted),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.captionTiny.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              value,
              style: AppTypography.captionSmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
