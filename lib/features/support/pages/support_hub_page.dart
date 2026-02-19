import 'package:flutter/material.dart';
import 'package:greenhive_app/core/service_locator.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/features/admin/data/models/faq.dart';

import '../services/support_service.dart';
import '../services/support_analytics.dart';
import '../services/faq_service.dart';
import 'ticket_list_page.dart';
import 'new_ticket_page.dart';

/// Main support hub page providing access to help resources.
///
/// Features:
/// - Quick actions: New ticket, view tickets
/// - FAQ links
/// - Contact options
class SupportHubPage extends StatefulWidget {
  const SupportHubPage({super.key});

  @override
  State<SupportHubPage> createState() => _SupportHubPageState();
}

class _SupportHubPageState extends State<SupportHubPage> {
  int _unreadCount = 0;
  late final FaqService _faqService;

  @override
  void initState() {
    super.initState();
    _faqService = sl<FaqService>();
    _loadUnreadCount();
    // Track hub opened
    sl<SupportAnalytics>().trackHubOpened();
  }

  Future<void> _loadUnreadCount() async {
    final count = await sl<SupportService>().getUnreadTicketCount();
    if (mounted) {
      setState(() => _unreadCount = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Help Center'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 24),

            // Quick actions
            _buildQuickActions(),
            const SizedBox(height: 32),

            // FAQ section
            _buildFaqSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.support_agent,
              color: AppColors.textPrimary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How can we help?',
                  style: AppTypography.headingSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We\'re here to help you with any questions or issues.',
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTypography.headingXSmall.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.add_circle_outline,
                title: 'New Ticket',
                subtitle: 'Report an issue',
                color: AppColors.primary,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewTicketPage()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.receipt_long,
                title: 'My Tickets',
                subtitle: 'View history',
                color: AppColors.info,
                badge: _unreadCount > 0 ? _unreadCount : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TicketListPage()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFaqSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequently Asked Questions',
          style: AppTypography.headingXSmall.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Faq>>(
          future: _faqService.getPublishedFaqs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Failed to load FAQs',
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              );
            }

            final faqs = snapshot.data ?? [];

            if (faqs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No FAQs available',
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: List.generate(
                faqs.length,
                (index) {
                  final faq = faqs[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _FaqCard(
                      faqId: faq.id,
                      question: faq.question,
                      answer: faq.answer,
                      faqService: _faqService,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }


}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final int? badge;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.textPrimary, size: 24),
                  ),
                  if (badge != null)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$badge',
                          style: AppTypography.captionTiny.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTypography.bodyEmphasis.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.captionSmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqCard extends StatefulWidget {
  final String faqId;
  final String question;
  final String answer;
  final FaqService faqService;

  const _FaqCard({
    required this.faqId,
    required this.question,
    required this.answer,
    required this.faqService,
  });

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () {
          setState(() => _isExpanded = !_isExpanded);
          // Record view when expanded
          if (!_isExpanded) {
            widget.faqService.recordFaqView(widget.faqId);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: AppTypography.bodyRegular.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                Text(
                  widget.answer,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Spacer(),
                    _HelpfulButton(
                      faqId: widget.faqId,
                      faqService: widget.faqService,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpfulButton extends StatefulWidget {
  final String faqId;
  final FaqService faqService;

  const _HelpfulButton({
    required this.faqId,
    required this.faqService,
  });

  @override
  State<_HelpfulButton> createState() => _HelpfulButtonState();
}

class _HelpfulButtonState extends State<_HelpfulButton> {
  bool? _isHelpful; // null = not voted, true = helpful, false = not helpful

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Was this helpful?',
          style: AppTypography.captionSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            Icons.thumb_up,
            size: 18,
            color: _isHelpful == true ? AppColors.primaryLight : AppColors.textMuted,
          ),
          onPressed: () {
            setState(() => _isHelpful = true);
            widget.faqService.markFaqHelpful(widget.faqId);
          },
        ),
        IconButton(
          icon: Icon(
            Icons.thumb_down,
            size: 18,
            color: _isHelpful == false ? AppColors.error : AppColors.textMuted,
          ),
          onPressed: () {
            setState(() => _isHelpful = false);
            widget.faqService.markFaqNotHelpful(widget.faqId);
          },
        ),
      ],
    );
  }
}


