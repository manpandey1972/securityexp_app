/// Centralised route-name constants.
///
/// All named routes registered in [MaterialApp.onGenerateRoute] are listed
/// here so that callers never hard-code string literals.
abstract final class AppRoutes {
  // ── Chat ──────────────────────────────────────────────────────────────
  static const String chat = '/chat';

  // ── Admin ─────────────────────────────────────────────────────────────
  static const String admin = '/admin';
  static const String adminTickets = '/admin/tickets';

  /// `/admin/tickets/:id`
  static String adminTicketDetail(String ticketId) =>
      '/admin/tickets/$ticketId';

  static const String adminFaqs = '/admin/faqs';

  /// `/admin/faqs/:id`  – pass `'new'` for the create-new variant.
  static String adminFaqEditor(String faqId) => '/admin/faqs/$faqId';

  static const String adminSkills = '/admin/skills';

  /// `/admin/skills/:id`  – pass `'new'` for the create-new variant.
  static String adminSkillEditor(String skillId) => '/admin/skills/$skillId';

  static const String adminUsers = '/admin/users';
}
