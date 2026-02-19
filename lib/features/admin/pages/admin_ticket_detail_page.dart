import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/features/admin/widgets/admin_section_wrapper.dart';
import 'package:securityexperts_app/shared/services/snackbar_service.dart';
import 'package:securityexperts_app/core/permissions/permission_types.dart';
import 'package:securityexperts_app/features/admin/presentation/view_models/admin_ticket_detail_view_model.dart';
import 'package:securityexperts_app/features/admin/widgets/ticket_detail/ticket_detail_widgets.dart';

/// Admin ticket detail page with management actions.
class AdminTicketDetailPage extends StatelessWidget {
  final String ticketId;

  const AdminTicketDetailPage({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context) {
    return AdminRouteGuard(
      minimumRole: UserRole.support,
      child: ChangeNotifierProvider(
        create: (_) =>
            AdminTicketDetailViewModel(ticketId: ticketId)..initialize(),
        child: const _AdminTicketDetailView(),
      ),
    );
  }
}

class _AdminTicketDetailView extends StatefulWidget {
  const _AdminTicketDetailView();

  @override
  State<_AdminTicketDetailView> createState() => _AdminTicketDetailViewState();
}

class _AdminTicketDetailViewState extends State<_AdminTicketDetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _replyController = TextEditingController();
  final _noteController = TextEditingController();
  final _scrollController = ScrollController();
  late FocusNode _replyFocusNode;
  late FocusNode _noteFocusNode;
  bool _descriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _replyFocusNode = FocusNode();
    _noteFocusNode = FocusNode();
    
    // Listen for focus changes to collapse description
    _replyFocusNode.addListener(_onInputFocusChanged);
    _noteFocusNode.addListener(_onInputFocusChanged);
  }

  void _onInputFocusChanged() {
    // If any input is focused and description is expanded, collapse it
    if ((_replyFocusNode.hasFocus || _noteFocusNode.hasFocus) && _descriptionExpanded) {
      setState(() {
        _descriptionExpanded = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _replyController.dispose();
    _noteController.dispose();
    _scrollController.dispose();
    _replyFocusNode.removeListener(_onInputFocusChanged);
    _noteFocusNode.removeListener(_onInputFocusChanged);
    _replyFocusNode.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AdminTicketDetailViewModel>();
    final state = viewModel.state;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          state.ticket?.ticketNumber ?? 'Ticket',
          style: AppTypography.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (state.ticket != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
              color: AppColors.surface,
              onSelected: (value) =>
                  _handleMenuAction(context, viewModel, value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'status',
                  child: Row(
                    children: [
                      Icon(Icons.flag, size: 20),
                      SizedBox(width: 8),
                      Text('Change Status'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'priority',
                  child: Row(
                    children: [
                      Icon(Icons.priority_high, size: 20),
                      SizedBox(width: 8),
                      Text('Change Priority'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'resolve',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 20),
                      SizedBox(width: 8),
                      Text('Resolve Ticket'),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            const Tab(text: 'Conversation'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Internal Notes'),
                  if (state.internalNotes.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        state.internalNotes.length.toString(),
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.primary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.ticket == null
          ? _buildErrorState(state.error!, viewModel)
          : Column(
              children: [
                // Ticket info header
                if (state.ticket != null)
                  TicketInfoHeader(
                    ticket: state.ticket!,
                    isExpanded: _descriptionExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _descriptionExpanded = expanded;
                      });
                    },
                    canExpand: !_replyFocusNode.hasFocus && !_noteFocusNode.hasFocus,
                  ),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Conversation tab
                      _buildConversationTab(viewModel, state),

                      // Internal notes tab
                      _buildInternalNotesTab(viewModel, state),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildErrorState(String error, AdminTicketDetailViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            error,
            style: AppTypography.bodyRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTab(AdminTicketDetailViewModel viewModel, state) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          // Messages list
          Expanded(
            child: state.messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet',
                      style: AppTypography.bodyRegular.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    reverse: true,
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message =
                          state.messages[state.messages.length - 1 - index];
                      return MessageBubble(message: message);
                    },
                  ),
          ),

          // Reply input
          _buildReplyInput(viewModel, state),
        ],
      ),
    );
  }

  Widget _buildReplyInput(AdminTicketDetailViewModel viewModel, state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                focusNode: _replyFocusNode,
                onChanged: viewModel.setReplyText,
                maxLines: null,
                style: AppTypography.bodyRegular.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Type your reply...',
                  hintStyle: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: state.isSending || state.replyText.trim().isEmpty
                  ? null
                  : () async {
                      final success = await viewModel.sendReply();
                      if (success) {
                        _replyController.clear();
                        SnackbarService.show('Reply sent');
                      }
                    },
              icon: state.isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.send,
                      color: state.replyText.trim().isEmpty
                          ? AppColors.textMuted
                          : AppColors.primary,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInternalNotesTab(AdminTicketDetailViewModel viewModel, state) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          // Notes list
          Expanded(
            child: state.internalNotes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.note_alt_outlined,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No internal notes',
                          style: AppTypography.bodyRegular.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add notes visible only to support staff',
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.internalNotes.length,
                    itemBuilder: (context, index) {
                      return InternalNoteCard(note: state.internalNotes[index]);
                    },
                  ),
          ),

          // Note input
          _buildNoteInput(viewModel, state),
        ],
      ),
    );
  }

  Widget _buildNoteInput(AdminTicketDetailViewModel viewModel, state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _noteController,
                focusNode: _noteFocusNode,
                onChanged: viewModel.setInternalNoteText,
                maxLines: null,
                style: AppTypography.bodyRegular.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Add internal note...',
                  hintStyle: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.warning.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed:
                  state.isSending || state.internalNoteText.trim().isEmpty
                  ? null
                  : () async {
                      final success = await viewModel.addInternalNote();
                      if (success) {
                        _noteController.clear();
                        SnackbarService.show('Note added');
                      }
                    },
              icon: state.isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.add_comment,
                      color: state.internalNoteText.trim().isEmpty
                          ? AppColors.textMuted
                          : AppColors.warning,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    AdminTicketDetailViewModel viewModel,
    String action,
  ) {
    switch (action) {
      case 'status':
        showStatusPicker(context, viewModel);
        break;
      case 'priority':
        showPriorityPicker(context, viewModel);
        break;
      case 'resolve':
        showResolveDialog(context, viewModel);
        break;
    }
  }
}
