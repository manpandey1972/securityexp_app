import 'package:securityexperts_app/data/models/models.dart';
import 'package:securityexperts_app/features/support/data/models/models.dart' as support_models;

/// Factory class for creating test data objects with sensible defaults
class TestDataFactory {
  // Counter for generating unique IDs
  static int _idCounter = 0;

  /// Generate a unique ID for test objects
  static String generateId([String prefix = 'test']) {
    _idCounter++;
    return '${prefix}_$_idCounter';
  }

  /// Reset the ID counter (useful in tearDown)
  static void resetIdCounter() {
    _idCounter = 0;
  }

  // ==========================================================================
  // User Factory
  // ==========================================================================

  /// Create a test User with default values
  static User createUser({
    String? id,
    String name = 'Test User',
    String? email,
    String? phone,
    List<String> roles = const ['Consumer'],
    List<String> languages = const ['English'],
    List<String> expertises = const [],
    List<String> fcmTokens = const [],
    List<String>? adminPermissions,
    Timestamp? createdTime,
    Timestamp? updatedTime,
    Timestamp? lastLogin,
    String? bio,
    String? profilePictureUrl,
    Timestamp? profilePictureUpdatedAt,
    bool? hasProfilePicture,
    bool notificationsEnabled = true,
    double? averageRating,
    int? totalRatings,
  }) {
    final userId = id ?? generateId('user');
    return User(
      id: userId,
      name: name,
      email: email ?? '$userId@test.com',
      phone: phone,
      roles: roles,
      languages: languages,
      expertises: expertises,
      fcmTokens: fcmTokens,
      adminPermissions: adminPermissions,
      createdTime: createdTime ?? Timestamp.now(),
      updatedTime: updatedTime,
      lastLogin: lastLogin,
      bio: bio,
      profilePictureUrl: profilePictureUrl,
      profilePictureUpdatedAt: profilePictureUpdatedAt,
      hasProfilePicture: hasProfilePicture ?? (profilePictureUrl != null),
      notificationsEnabled: notificationsEnabled,
      averageRating: averageRating,
      totalRatings: totalRatings,
    );
  }

  /// Create a test Expert user
  static User createExpert({
    String? id,
    String name = 'Test Expert',
    String? email,
    List<String> expertises = const ['Agriculture', 'Gardening'],
    String? bio,
    double? averageRating,
    int? totalRatings,
  }) {
    return createUser(
      id: id,
      name: name,
      email: email,
      roles: ['Expert'],
      expertises: expertises,
      bio: bio ?? 'Expert in ${expertises.join(", ")}',
      averageRating: averageRating ?? 4.5,
      totalRatings: totalRatings ?? 10,
    );
  }

  /// Create a test Admin user
  static User createAdmin({
    String? id,
    String name = 'Test Admin',
    String? email,
    List<String>? adminPermissions,
  }) {
    return createUser(
      id: id,
      name: name,
      email: email,
      roles: ['Admin'],
      adminPermissions: adminPermissions ?? [
        'manage_users',
        'manage_content',
        'view_reports',
      ],
    );
  }

  // ==========================================================================
  // Message Factory
  // ==========================================================================

  /// Create a test Message with default values
  static Message createMessage({
    String? id,
    String? senderId,
    MessageType type = MessageType.text,
    String text = 'Test message',
    String? mediaUrl,
    String? replyToMessageId,
    Message? replyToMessage,
    Timestamp? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? generateId('msg'),
      senderId: senderId ?? generateId('sender'),
      type: type,
      text: text,
      mediaUrl: mediaUrl,
      replyToMessageId: replyToMessageId,
      replyToMessage: replyToMessage,
      timestamp: timestamp ?? Timestamp.now(),
      metadata: metadata,
    );
  }

  /// Create a test image Message
  static Message createImageMessage({
    String? id,
    String? senderId,
    String? mediaUrl,
    Timestamp? timestamp,
  }) {
    return createMessage(
      id: id,
      senderId: senderId,
      type: MessageType.image,
      text: '',
      mediaUrl: mediaUrl ?? 'https://example.com/image.jpg',
      timestamp: timestamp,
    );
  }

  /// Create a test audio Message
  static Message createAudioMessage({
    String? id,
    String? senderId,
    String? mediaUrl,
    int durationMs = 30000,
    Timestamp? timestamp,
  }) {
    return createMessage(
      id: id,
      senderId: senderId,
      type: MessageType.audio,
      text: '',
      mediaUrl: mediaUrl ?? 'https://example.com/audio.m4a',
      timestamp: timestamp,
      metadata: {'duration_ms': durationMs},
    );
  }

  /// Create a test video Message
  static Message createVideoMessage({
    String? id,
    String? senderId,
    String? mediaUrl,
    String? thumbnailUrl,
    Timestamp? timestamp,
  }) {
    return createMessage(
      id: id,
      senderId: senderId,
      type: MessageType.video,
      text: '',
      mediaUrl: mediaUrl ?? 'https://example.com/video.mp4',
      timestamp: timestamp,
      metadata: {
        'thumbnail_url': thumbnailUrl ?? 'https://example.com/thumb.jpg',
      },
    );
  }

  /// Create a test system Message
  static Message createSystemMessage({
    String? id,
    String text = 'System notification',
    Timestamp? timestamp,
  }) {
    return createMessage(
      id: id,
      senderId: 'system',
      type: MessageType.system,
      text: text,
      timestamp: timestamp,
    );
  }

  // ==========================================================================
  // Room Factory
  // ==========================================================================

  /// Create a test Room with default values
  static Room createRoom({
    String? id,
    List<String>? participants,
    String lastMessage = 'Last message',
    Timestamp? lastMessageTime,
    Timestamp? createdAt,
  }) {
    return Room(
      id: id ?? generateId('room'),
      participants: participants ?? [generateId('user'), generateId('user')],
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime ?? Timestamp.now(),
      createdAt: createdAt ?? Timestamp.now(),
    );
  }

  // ==========================================================================
  // Product Factory
  // ==========================================================================

  /// Create a test Product with default values
  static Product createProduct({
    String? id,
    String name = 'Test Product',
    double price = 9.99,
  }) {
    return Product(
      id: id ?? generateId('product'),
      name: name,
      price: price,
    );
  }

  // ==========================================================================
  // Call Factory
  // ==========================================================================

  /// Create a test Call with default values
  static Call createCall({
    String? id,
    String? callerId,
    String? calleeId,
    Map<String, dynamic>? offer,
    Map<String, dynamic>? answer,
    bool isVideo = true,
    String status = 'pending',
    Timestamp? createdAt,
    Timestamp? answeredAt,
    Timestamp? endedAt,
  }) {
    return Call(
      id: id ?? generateId('call'),
      callerId: callerId ?? generateId('caller'),
      calleeId: calleeId ?? generateId('callee'),
      offer: offer,
      answer: answer,
      isVideo: isVideo,
      status: status,
      createdAt: createdAt ?? Timestamp.now(),
      answeredAt: answeredAt,
      endedAt: endedAt,
    );
  }

  // ==========================================================================
  // Support Ticket Factory
  // ==========================================================================

  /// Create a test SupportTicket with default values
  static support_models.SupportTicket createSupportTicket({
    String? id,
    String ticketNumber = 'GH-2026-00001',
    String? userId,
    String userEmail = 'user@example.com',
    String? userName,
    support_models.TicketType type = support_models.TicketType.support,
    support_models.TicketCategory category = support_models.TicketCategory.other,
    String subject = 'Test Support Ticket',
    String description = 'This is a test support ticket description.',
    support_models.TicketStatus status = support_models.TicketStatus.open,
    support_models.TicketPriority priority = support_models.TicketPriority.medium,
    String? assignedTo,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? closedAt,
  }) {
    return support_models.SupportTicket(
      id: id ?? generateId('ticket'),
      ticketNumber: ticketNumber,
      userId: userId,
      userEmail: userEmail,
      userName: userName,
      type: type,
      category: category,
      subject: subject,
      description: description,
      deviceContext: support_models.DeviceContext(
        platform: 'iOS',
        osVersion: '17.0',
        appVersion: '1.0.0',
        buildNumber: '1',
        locale: 'en_US',
        timezone: 'UTC',
      ),
      status: status,
      priority: priority,
      assignedTo: assignedTo,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      lastActivityAt: updatedAt ?? DateTime.now(),
    );
  }

  // ==========================================================================
  // Support Message Factory
  // ==========================================================================

  /// Create a test SupportMessage with default values
  static support_models.SupportMessage createSupportMessage({
    String? id,
    String? ticketId,
    String senderId = 'support_agent_1',
    String senderName = 'Support Agent',
    support_models.MessageSenderType senderType = support_models.MessageSenderType.support,
    String content = 'This is a test support message.',
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return support_models.SupportMessage(
      id: id ?? generateId('msg'),
      ticketId: ticketId ?? generateId('ticket'),
      senderId: senderId,
      senderType: senderType,
      senderName: senderName,
      content: content,
      createdAt: createdAt ?? DateTime.now(),
      readAt: readAt,
    );
  }


  // ==========================================================================
  // List Factories (for batch testing)
  // ==========================================================================

  /// Create a list of test Users
  static List<User> createUsers(int count, {List<String> roles = const ['Consumer']}) {
    return List.generate(count, (i) => createUser(
      id: 'user_$i',
      name: 'User $i',
      roles: roles,
    ));
  }

  /// Create a list of test Messages in a conversation
  static List<Message> createConversation({
    required String user1Id,
    required String user2Id,
    int messageCount = 10,
  }) {
    final messages = <Message>[];
    for (int i = 0; i < messageCount; i++) {
      messages.add(createMessage(
        id: 'msg_$i',
        senderId: i.isEven ? user1Id : user2Id,
        text: 'Message $i',
        timestamp: Timestamp.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch - ((messageCount - i) * 60000),
        ),
      ));
    }
    return messages;
  }

  /// Create a list of test Products
  static List<Product> createProducts(int count) {
    return List.generate(count, (i) => createProduct(
      id: 'product_$i',
      name: 'Product $i',
      price: (i + 1) * 9.99,
    ));
  }
}
