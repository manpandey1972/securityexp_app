import 'package:greenhive_app/features/admin/data/models/faq.dart';
import 'package:greenhive_app/features/admin/services/admin_ticket_service.dart';
import 'package:greenhive_app/features/admin/services/admin_user_service.dart';
import 'package:greenhive_app/features/admin/services/admin_skills_service.dart';
import 'package:greenhive_app/features/support/data/models/models.dart';

// ============= Admin Dashboard State =============

/// State for admin dashboard page.
class AdminDashboardState {
  final bool isLoading;
  final String? error;
  final TicketStats stats;
  final List<SupportTicket> recentTickets;

  const AdminDashboardState({
    this.isLoading = true,
    this.error,
    this.stats = const TicketStats(),
    this.recentTickets = const [],
  });

  AdminDashboardState copyWith({
    bool? isLoading,
    String? error,
    TicketStats? stats,
    List<SupportTicket>? recentTickets,
  }) {
    return AdminDashboardState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      stats: stats ?? this.stats,
      recentTickets: recentTickets ?? this.recentTickets,
    );
  }
}

// ============= Admin Users State =============

/// Filter options for admin users list.
class AdminUserFilters {
  final String? roleFilter;
  final bool? suspendedFilter;
  final String searchQuery;

  const AdminUserFilters({
    this.roleFilter,
    this.suspendedFilter,
    this.searchQuery = '',
  });

  AdminUserFilters copyWith({
    String? roleFilter,
    bool? suspendedFilter,
    String? searchQuery,
    bool clearRole = false,
    bool clearSuspended = false,
  }) {
    return AdminUserFilters(
      roleFilter: clearRole ? null : (roleFilter ?? this.roleFilter),
      suspendedFilter:
          clearSuspended ? null : (suspendedFilter ?? this.suspendedFilter),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasActiveFilters =>
      roleFilter != null || suspendedFilter != null || searchQuery.isNotEmpty;

  int get activeFilterCount {
    int count = 0;
    if (roleFilter != null) count++;
    if (suspendedFilter != null) count++;
    return count;
  }
}

/// State for admin users list page.
class AdminUsersState {
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final List<AdminUser> users;
  final Map<String, int> stats;
  final AdminUserFilters filters;
  final bool hasMore;

  const AdminUsersState({
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.users = const [],
    this.stats = const {},
    this.filters = const AdminUserFilters(),
    this.hasMore = true,
  });

  AdminUsersState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    List<AdminUser>? users,
    Map<String, int>? stats,
    AdminUserFilters? filters,
    bool? hasMore,
    bool clearError = false,
  }) {
    return AdminUsersState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      users: users ?? this.users,
      stats: stats ?? this.stats,
      filters: filters ?? this.filters,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  /// Filter users locally by search query.
  List<AdminUser> get filteredUsers {
    if (filters.searchQuery.isEmpty) return users;

    final query = filters.searchQuery.toLowerCase();
    return users.where((user) {
      return user.name.toLowerCase().contains(query) ||
          (user.email?.toLowerCase().contains(query) ?? false) ||
          (user.phone?.contains(query) ?? false);
    }).toList();
  }
}

// ============= Admin Skills State =============

/// Filter options for admin skills list.
class AdminSkillFilters {
  final String? categoryFilter;
  final bool? activeFilter;
  final String searchQuery;

  const AdminSkillFilters({
    this.categoryFilter,
    this.activeFilter,
    this.searchQuery = '',
  });

  AdminSkillFilters copyWith({
    String? categoryFilter,
    bool? activeFilter,
    String? searchQuery,
    bool clearCategory = false,
    bool clearActive = false,
  }) {
    return AdminSkillFilters(
      categoryFilter:
          clearCategory ? null : (categoryFilter ?? this.categoryFilter),
      activeFilter: clearActive ? null : (activeFilter ?? this.activeFilter),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasActiveFilters =>
      categoryFilter != null || activeFilter != null || searchQuery.isNotEmpty;

  int get activeFilterCount {
    int count = 0;
    if (categoryFilter != null) count++;
    if (activeFilter != null) count++;
    return count;
  }
}

/// State for admin skills list page.
class AdminSkillsState {
  final bool isLoading;
  final String? error;
  final List<AdminSkill> skills;
  final List<SkillCategory> categories;
  final Map<String, int> stats;
  final AdminSkillFilters filters;

  const AdminSkillsState({
    this.isLoading = true,
    this.error,
    this.skills = const [],
    this.categories = const [],
    this.stats = const {},
    this.filters = const AdminSkillFilters(),
  });

  AdminSkillsState copyWith({
    bool? isLoading,
    String? error,
    List<AdminSkill>? skills,
    List<SkillCategory>? categories,
    Map<String, int>? stats,
    AdminSkillFilters? filters,
    bool clearError = false,
  }) {
    return AdminSkillsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      skills: skills ?? this.skills,
      categories: categories ?? this.categories,
      stats: stats ?? this.stats,
      filters: filters ?? this.filters,
    );
  }

  /// Filter skills locally by search query.
  List<AdminSkill> get filteredSkills {
    if (filters.searchQuery.isEmpty) return skills;

    final query = filters.searchQuery.toLowerCase();
    return skills.where((skill) {
      return skill.name.toLowerCase().contains(query) ||
          skill.category.toLowerCase().contains(query) ||
          skill.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }
}

// ============= Admin FAQs State =============

/// Filter options for admin FAQs list.
class AdminFaqFilters {
  final String? categoryFilter;
  final bool? publishedFilter;
  final String searchQuery;

  const AdminFaqFilters({
    this.categoryFilter,
    this.publishedFilter,
    this.searchQuery = '',
  });

  AdminFaqFilters copyWith({
    String? categoryFilter,
    bool? publishedFilter,
    String? searchQuery,
    bool clearCategory = false,
    bool clearPublished = false,
  }) {
    return AdminFaqFilters(
      categoryFilter:
          clearCategory ? null : (categoryFilter ?? this.categoryFilter),
      publishedFilter:
          clearPublished ? null : (publishedFilter ?? this.publishedFilter),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasActiveFilters =>
      categoryFilter != null ||
      publishedFilter != null ||
      searchQuery.isNotEmpty;

  int get activeFilterCount {
    int count = 0;
    if (categoryFilter != null) count++;
    if (publishedFilter != null) count++;
    return count;
  }
}

/// State for admin FAQs list page.
class AdminFaqsState {
  final bool isLoading;
  final String? error;
  final List<Faq> faqs;
  final List<FaqCategory> categories;
  final Map<String, int> stats;
  final AdminFaqFilters filters;

  const AdminFaqsState({
    this.isLoading = true,
    this.error,
    this.faqs = const [],
    this.categories = const [],
    this.stats = const {},
    this.filters = const AdminFaqFilters(),
  });

  AdminFaqsState copyWith({
    bool? isLoading,
    String? error,
    List<Faq>? faqs,
    List<FaqCategory>? categories,
    Map<String, int>? stats,
    AdminFaqFilters? filters,
    bool clearError = false,
  }) {
    return AdminFaqsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      faqs: faqs ?? this.faqs,
      categories: categories ?? this.categories,
      stats: stats ?? this.stats,
      filters: filters ?? this.filters,
    );
  }

  /// Filter FAQs locally by search query.
  List<Faq> get filteredFaqs {
    if (filters.searchQuery.isEmpty) return faqs;

    final query = filters.searchQuery.toLowerCase();
    return faqs.where((faq) {
      return faq.question.toLowerCase().contains(query) ||
          faq.answer.toLowerCase().contains(query) ||
          faq.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }
}

// ============= Admin Tickets State =============

/// Filter options for admin tickets list.
class AdminTicketFilters {
  final TicketStatus? status;
  final TicketPriority? priority;
  final TicketCategory? category;
  final bool unassignedOnly;
  final String searchQuery;

  const AdminTicketFilters({
    this.status,
    this.priority,
    this.category,
    this.unassignedOnly = false,
    this.searchQuery = '',
  });

  AdminTicketFilters copyWith({
    TicketStatus? status,
    TicketPriority? priority,
    TicketCategory? category,
    bool? unassignedOnly,
    String? searchQuery,
    bool clearStatus = false,
    bool clearPriority = false,
    bool clearCategory = false,
  }) {
    return AdminTicketFilters(
      status: clearStatus ? null : (status ?? this.status),
      priority: clearPriority ? null : (priority ?? this.priority),
      category: clearCategory ? null : (category ?? this.category),
      unassignedOnly: unassignedOnly ?? this.unassignedOnly,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasActiveFilters =>
      status != null ||
      priority != null ||
      category != null ||
      unassignedOnly ||
      searchQuery.isNotEmpty;

  int get activeFilterCount {
    int count = 0;
    if (status != null) count++;
    if (priority != null) count++;
    if (category != null) count++;
    if (unassignedOnly) count++;
    return count;
  }
}

/// State for admin tickets list page.
class AdminTicketsState {
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final List<SupportTicket> tickets;
  final AdminTicketFilters filters;
  final bool hasMore;

  const AdminTicketsState({
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.tickets = const [],
    this.filters = const AdminTicketFilters(),
    this.hasMore = true,
  });

  AdminTicketsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    List<SupportTicket>? tickets,
    AdminTicketFilters? filters,
    bool? hasMore,
  }) {
    return AdminTicketsState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      tickets: tickets ?? this.tickets,
      filters: filters ?? this.filters,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  /// Filter tickets locally by search query.
  List<SupportTicket> get filteredTickets {
    if (filters.searchQuery.isEmpty) return tickets;

    final query = filters.searchQuery.toLowerCase();
    return tickets.where((ticket) {
      return ticket.ticketNumber.toLowerCase().contains(query) ||
          ticket.subject.toLowerCase().contains(query) ||
          ticket.userEmail.toLowerCase().contains(query) ||
          (ticket.userName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }
}

/// State for admin ticket detail page.
class AdminTicketDetailState {
  final bool isLoading;
  final bool isSending;
  final bool isUpdating;
  final String? error;
  final SupportTicket? ticket;
  final List<SupportMessage> messages;
  final List<InternalNote> internalNotes;
  final String replyText;
  final String internalNoteText;
  final bool showInternalNotes;

  const AdminTicketDetailState({
    this.isLoading = true,
    this.isSending = false,
    this.isUpdating = false,
    this.error,
    this.ticket,
    this.messages = const [],
    this.internalNotes = const [],
    this.replyText = '',
    this.internalNoteText = '',
    this.showInternalNotes = false,
  });

  AdminTicketDetailState copyWith({
    bool? isLoading,
    bool? isSending,
    bool? isUpdating,
    String? error,
    SupportTicket? ticket,
    List<SupportMessage>? messages,
    List<InternalNote>? internalNotes,
    String? replyText,
    String? internalNoteText,
    bool? showInternalNotes,
  }) {
    return AdminTicketDetailState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isUpdating: isUpdating ?? this.isUpdating,
      error: error,
      ticket: ticket ?? this.ticket,
      messages: messages ?? this.messages,
      internalNotes: internalNotes ?? this.internalNotes,
      replyText: replyText ?? this.replyText,
      internalNoteText: internalNoteText ?? this.internalNoteText,
      showInternalNotes: showInternalNotes ?? this.showInternalNotes,
    );
  }
}
