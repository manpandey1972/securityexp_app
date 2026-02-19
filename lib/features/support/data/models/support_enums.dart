import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_colors.dart';

/// Types of support tickets that users can submit
enum TicketType {
  bug,
  featureRequest,
  feedback,
  support,
  account,
  payment;

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case TicketType.bug:
        return 'Bug Report';
      case TicketType.featureRequest:
        return 'Feature Request';
      case TicketType.feedback:
        return 'Feedback';
      case TicketType.support:
        return 'Support Request';
      case TicketType.account:
        return 'Account Issue';
      case TicketType.payment:
        return 'Payment Issue';
    }
  }

  /// Emoji icon for the ticket type
  String get emoji {
    switch (this) {
      case TicketType.bug:
        return '🐛';
      case TicketType.featureRequest:
        return '💡';
      case TicketType.feedback:
        return '💬';
      case TicketType.support:
        return '🆘';
      case TicketType.account:
        return '👤';
      case TicketType.payment:
        return '💳';
    }
  }

  /// Description for the ticket type
  String get description {
    switch (this) {
      case TicketType.bug:
        return 'Report crashes, errors, or unexpected behavior';
      case TicketType.featureRequest:
        return 'Suggest new features or improvements';
      case TicketType.feedback:
        return 'Share your thoughts and suggestions';
      case TicketType.support:
        return 'Get help with using the app';
      case TicketType.account:
        return 'Issues with your account or profile';
      case TicketType.payment:
        return 'Billing or payment related issues';
    }
  }

  /// Convert to JSON string
  String toJson() => name;

  /// Create from JSON string
  static TicketType fromJson(String json) {
    return TicketType.values.firstWhere(
      (e) => e.name == json,
      orElse: () => TicketType.support,
    );
  }
}

/// Categories for organizing support tickets
enum TicketCategory {
  calling,
  chat,
  profile,
  notifications,
  experts,
  performance,
  other;

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case TicketCategory.calling:
        return 'Calling & Video';
      case TicketCategory.chat:
        return 'Chat & Messaging';
      case TicketCategory.profile:
        return 'Profile & Settings';
      case TicketCategory.notifications:
        return 'Notifications';
      case TicketCategory.experts:
        return 'Experts';
      case TicketCategory.performance:
        return 'Performance';
      case TicketCategory.other:
        return 'Other';
    }
  }

  /// Icon for the category
  IconData get icon {
    switch (this) {
      case TicketCategory.calling:
        return Icons.video_call;
      case TicketCategory.chat:
        return Icons.chat;
      case TicketCategory.profile:
        return Icons.person;
      case TicketCategory.notifications:
        return Icons.notifications;
      case TicketCategory.experts:
        return Icons.school;
      case TicketCategory.performance:
        return Icons.speed;
      case TicketCategory.other:
        return Icons.help_outline;
    }
  }

  /// Convert to JSON string
  String toJson() => name;

  /// Create from JSON string
  static TicketCategory fromJson(String json) {
    return TicketCategory.values.firstWhere(
      (e) => e.name == json,
      orElse: () => TicketCategory.other,
    );
  }
}

/// Status of a support ticket
enum TicketStatus {
  open,
  inReview,
  inProgress,
  resolved,
  closed;

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case TicketStatus.open:
        return 'Open';
      case TicketStatus.inReview:
        return 'In Review';
      case TicketStatus.inProgress:
        return 'In Progress';
      case TicketStatus.resolved:
        return 'Resolved';
      case TicketStatus.closed:
        return 'Closed';
    }
  }

  /// Color for the status
  Color get color {
    switch (this) {
      case TicketStatus.open:
        return AppColors.info;
      case TicketStatus.inReview:
        return AppColors.orange;
      case TicketStatus.inProgress:
        return AppColors.purple;
      case TicketStatus.resolved:
        return AppColors.success;
      case TicketStatus.closed:
        return AppColors.neutral;
    }
  }

  /// Convert to JSON string
  String toJson() {
    switch (this) {
      case TicketStatus.inReview:
        return 'in_review';
      case TicketStatus.inProgress:
        return 'in_progress';
      default:
        return name;
    }
  }

  /// Create from JSON string
  static TicketStatus fromJson(String json) {
    switch (json) {
      case 'in_review':
        return TicketStatus.inReview;
      case 'in_progress':
        return TicketStatus.inProgress;
      default:
        return TicketStatus.values.firstWhere(
          (e) => e.name == json,
          orElse: () => TicketStatus.open,
        );
    }
  }
}

/// Priority level for support tickets
enum TicketPriority {
  critical,
  high,
  medium,
  low;

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case TicketPriority.critical:
        return 'Critical';
      case TicketPriority.high:
        return 'High';
      case TicketPriority.medium:
        return 'Medium';
      case TicketPriority.low:
        return 'Low';
    }
  }

  /// Color for the priority
  Color get color {
    switch (this) {
      case TicketPriority.critical:
        return AppColors.error;
      case TicketPriority.high:
        return AppColors.warning;
      case TicketPriority.medium:
        return AppColors.ratingStar;
      case TicketPriority.low:
        return AppColors.success;
    }
  }

  /// Get default priority based on ticket type
  static TicketPriority fromTicketType(TicketType type) {
    switch (type) {
      case TicketType.payment:
        return TicketPriority.critical;
      case TicketType.bug:
      case TicketType.account:
        return TicketPriority.high;
      case TicketType.support:
        return TicketPriority.medium;
      case TicketType.featureRequest:
      case TicketType.feedback:
        return TicketPriority.low;
    }
  }

  /// Convert to JSON string
  String toJson() => name;

  /// Create from JSON string
  static TicketPriority fromJson(String json) {
    return TicketPriority.values.firstWhere(
      (e) => e.name == json,
      orElse: () => TicketPriority.medium,
    );
  }
}

/// Type of message sender in a support conversation
enum MessageSenderType {
  user,
  support,
  system;

  /// Convert to JSON string
  String toJson() => name;

  /// Create from JSON string
  static MessageSenderType fromJson(String json) {
    return MessageSenderType.values.firstWhere(
      (e) => e.name == json,
      orElse: () => MessageSenderType.user,
    );
  }
}

/// Type of system message
enum SystemMessageType {
  statusChange,
  assignmentChange,
  autoResponse,
  ticketCreated,
  ticketResolved,
  ticketClosed;

  /// Convert to JSON string
  String toJson() {
    switch (this) {
      case SystemMessageType.statusChange:
        return 'status_change';
      case SystemMessageType.assignmentChange:
        return 'assignment_change';
      case SystemMessageType.autoResponse:
        return 'auto_response';
      case SystemMessageType.ticketCreated:
        return 'ticket_created';
      case SystemMessageType.ticketResolved:
        return 'ticket_resolved';
      case SystemMessageType.ticketClosed:
        return 'ticket_closed';
    }
  }

  /// Create from JSON string
  static SystemMessageType? fromJson(String? json) {
    if (json == null) return null;
    switch (json) {
      case 'status_change':
        return SystemMessageType.statusChange;
      case 'assignment_change':
        return SystemMessageType.assignmentChange;
      case 'auto_response':
        return SystemMessageType.autoResponse;
      case 'ticket_created':
        return SystemMessageType.ticketCreated;
      case 'ticket_resolved':
        return SystemMessageType.ticketResolved;
      case 'ticket_closed':
        return SystemMessageType.ticketClosed;
      default:
        return null;
    }
  }
}

/// Resolution type for closed tickets
enum ResolutionType {
  fixed,
  duplicate,
  wontFix,
  invalid,
  userResolved;

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case ResolutionType.fixed:
        return 'Fixed';
      case ResolutionType.duplicate:
        return 'Duplicate';
      case ResolutionType.wontFix:
        return "Won't Fix";
      case ResolutionType.invalid:
        return 'Invalid';
      case ResolutionType.userResolved:
        return 'Resolved by User';
    }
  }

  /// Convert to JSON string
  String toJson() {
    switch (this) {
      case ResolutionType.wontFix:
        return 'wont_fix';
      case ResolutionType.userResolved:
        return 'user_resolved';
      default:
        return name;
    }
  }

  /// Create from JSON string
  static ResolutionType? fromJson(String? json) {
    if (json == null) return null;
    switch (json) {
      case 'wont_fix':
        return ResolutionType.wontFix;
      case 'user_resolved':
        return ResolutionType.userResolved;
      default:
        return ResolutionType.values.firstWhere(
          (e) => e.name == json,
          orElse: () => ResolutionType.fixed,
        );
    }
  }
}
