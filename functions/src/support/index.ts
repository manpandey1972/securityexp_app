/**
 * Support Ticket Cloud Functions
 *
 * Handles ticket lifecycle events including:
 * - Ticket number generation
 * - Welcome message creation
 * - Notifications to support team
 * - Auto-close functionality
 */

import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import {Timestamp, FieldValue} from "firebase-admin/firestore";
import {db, sendFCMToUser, getUserData} from "../utils";
import {shouldSendPushNotification} from "../presence/checkPresenceBeforePush";
const TICKETS_COLLECTION = "support_tickets";
const MESSAGES_SUBCOLLECTION = "messages";
const COUNTERS_COLLECTION = "system_counters";

// ============================================================================
// Type Definitions
// ============================================================================

interface SupportTicket {
  id?: string;
  ticketNumber?: string;
  userId: string;
  userEmail?: string;
  userName?: string;
  type: string;
  category: string;
  subject: string;
  description: string;
  status: string;
  priority: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  lastActivityAt: Timestamp;
  messageCount: number;
  hasUnreadSupportMessages: boolean;
}

interface SupportMessage {
  id?: string;
  ticketId: string;
  senderType: "user" | "support" | "system";
  senderId?: string;
  senderName?: string;
  content: string;
  systemMessageType?: string;
  createdAt: Timestamp;
  readAt?: Timestamp | null;
}

// ============================================================================
// Ticket Number Generation
// ============================================================================

/**
 * Generate a unique ticket number in format: GH-YYYY-XXXXX
 * Uses atomic counter to ensure uniqueness
 */
async function generateTicketNumber(): Promise<string> {
  const counterRef = db.collection(COUNTERS_COLLECTION).doc("support_tickets");
  const year = new Date().getFullYear();

  try {
    const result = await db.runTransaction(async (transaction) => {
      const counterDoc = await transaction.get(counterRef);

      let currentYear = year;
      let count = 1;

      if (counterDoc.exists) {
        const data = counterDoc.data();
        if (data) {
          currentYear = data.year || year;
          count = data.count || 0;
        }

        // Reset counter if new year
        if (currentYear !== year) {
          count = 1;
          currentYear = year;
        } else {
          count += 1;
        }
      }

      transaction.set(counterRef, {
        year: currentYear,
        count: count,
        lastUpdated: FieldValue.serverTimestamp(),
      });

      return count;
    });

    // Format: GH-2026-00001
    const paddedCount = result.toString().padStart(5, "0");
    return `GH-${year}-${paddedCount}`;
  } catch (error) {
    logger.error("Error generating ticket number:", error);
    // Fallback to timestamp-based number
    const timestamp = Date.now().toString(36).toUpperCase();
    return `GH-${year}-${timestamp}`;
  }
}

// ============================================================================
// System Message Creation
// ============================================================================

/**
 * Create a system message for a ticket
 * @param ticketId - The ticket ID
 * @param content - Message content
 * @param systemMessageType - Type of system message
 */
async function createSystemMessage(
  ticketId: string,
  content: string,
  systemMessageType: string
): Promise<void> {
  const messagesRef = db
    .collection(TICKETS_COLLECTION)
    .doc(ticketId)
    .collection(MESSAGES_SUBCOLLECTION);

  const message: SupportMessage = {
    ticketId,
    senderType: "system",
    senderId: "system",
    senderName: "Support",
    content,
    systemMessageType,
    createdAt: Timestamp.now(),
  };

  await messagesRef.add(message);
  logger.info(
    `Created system message for ticket ${ticketId}: ${systemMessageType}`
  );
}

// ============================================================================
// Cloud Function: onTicketCreate
// ============================================================================

/**
 * Triggered when a new support ticket is created.
 *
 * Actions:
 * 1. Generate unique ticket number
 * 2. Create welcome system message
 * 3. Notify support team for high-priority tickets
 */
export const onTicketCreate = onDocumentCreated(
  {
    document: `${TICKETS_COLLECTION}/{ticketId}`,
    database: "green-hive-db",
  },
  async (event) => {
    const ticketId = event.params.ticketId;
    const ticketData = event.data?.data() as SupportTicket | undefined;

    if (!ticketData) {
      logger.warn(`No data found for ticket ${ticketId}`);
      return;
    }

    logger.info(`Processing new ticket: ${ticketId}`, {
      type: ticketData.type,
      category: ticketData.category,
      priority: ticketData.priority,
    });

    try {
      // 1. Generate ticket number
      const ticketNumber = await generateTicketNumber();

      // 2. Update ticket with generated number
      await db.collection(TICKETS_COLLECTION).doc(ticketId).update({
        ticketNumber,
        updatedAt: FieldValue.serverTimestamp(),
      });

      logger.info(`Assigned ticket number ${ticketNumber} to ${ticketId}`);

      // 3. Create welcome system message
      const welcomeMessage = getWelcomeMessage(ticketData.type, ticketNumber);
      await createSystemMessage(ticketId, welcomeMessage, "ticket_created");

      // 4. Update message count
      await db.collection(TICKETS_COLLECTION).doc(ticketId).update({
        messageCount: FieldValue.increment(1),
      });

      // 5. Notify support team for urgent tickets
      if (ticketData.priority === "critical" || ticketData.priority === "high") {
        await notifySupportTeam(ticketId, ticketData, ticketNumber);
      }

      logger.info(`Successfully processed ticket creation: ${ticketId}`);
    } catch (error) {
      logger.error(`Error processing ticket ${ticketId}:`, error);
    }
  }
);

/**
 * Generate welcome message based on ticket type
 * @param ticketType - Type of ticket (bug, feature_request, etc.)
 * @param ticketNumber - Generated ticket number
 * @return Welcome message string
 */
function getWelcomeMessage(ticketType: string, ticketNumber: string): string {
  const baseMessage = `Your ticket ${ticketNumber} has been created. `;

  const typeMessages: Record<string, string> = {
    bug:
      "We're sorry you encountered an issue. Our team will investigate and get back to you as soon as possible.",
    feature_request:
      "Thank you for your suggestion! We value your feedback and will review your request.",
    feedback:
      "Thank you for sharing your thoughts with us. Your feedback helps us improve.",
    support: "Our support team has received your request and will respond shortly.",
    account: "We've received your account inquiry. Someone will assist you soon.",
    payment:
      "We've received your payment-related query. Our team will review it promptly.",
  };

  const defaultMsg = "Our team will review your request and respond shortly.";
  return baseMessage + (typeMessages[ticketType] || defaultMsg);
}

/**
 * Notify support team about high-priority tickets
 * @param ticketId - The ticket ID
 * @param ticket - The ticket data
 * @param ticketNumber - The generated ticket number
 */
async function notifySupportTeam(
  ticketId: string,
  ticket: SupportTicket,
  ticketNumber: string
): Promise<void> {
  // In a production app, this would send notifications to support staff
  // For now, we log and could send to a Slack webhook or email

  logger.info(`🚨 HIGH PRIORITY TICKET: ${ticketNumber}`, {
    ticketId,
    type: ticket.type,
    category: ticket.category,
    priority: ticket.priority,
    subject: ticket.subject,
    userId: ticket.userId,
  });

  // TODO: Implement notification to support team
  // Options:
  // - Send to Slack webhook
  // - Send email to support@greenhive.app
  // - Update a support dashboard collection
}

// ============================================================================
// Cloud Function: onMessageCreate
// ============================================================================

/**
 * Triggered when a new message is added to a ticket.
 *
 * Actions:
 * 1. Update ticket lastActivityAt and messageCount
 * 2. If from support, notify user via push notification
 * 3. Update unread flags
 */
export const onSupportMessageCreate = onDocumentCreated(
  {
    document: `${TICKETS_COLLECTION}/{ticketId}/${MESSAGES_SUBCOLLECTION}/{messageId}`,
    database: "green-hive-db",
  },
  async (event) => {
    const {ticketId, messageId} = event.params;
    const messageData = event.data?.data() as SupportMessage | undefined;

    if (!messageData) {
      logger.warn(`No message data found: ${ticketId}/${messageId}`);
      return;
    }

    logger.info(`Processing message: ${messageId} for ticket ${ticketId}`, {
      senderType: messageData.senderType,
    });

    try {
      const ticketRef = db.collection(TICKETS_COLLECTION).doc(ticketId);

      // 1. Update ticket metadata
      const updates: Record<string, unknown> = {
        lastActivityAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        messageCount: FieldValue.increment(1),
      };

      // 2. If message is from support, mark ticket as having unread messages
      if (messageData.senderType === "support") {
        updates.hasUnreadSupportMessages = true;

        // Get ticket to find user for notification
        const ticketDoc = await ticketRef.get();
        if (ticketDoc.exists) {
          const ticket = ticketDoc.data() as SupportTicket;
          await sendSupportMessageNotification(ticket, messageData);
        }
      }

      await ticketRef.update(updates);

      logger.info(`Updated ticket ${ticketId} metadata`);
    } catch (error) {
      logger.error(`Error processing message ${messageId}:`, error);
    }
  }
);

/**
 * Send push notification to user when support responds
 */
async function sendSupportMessageNotification(
  ticket: SupportTicket,
  message: SupportMessage
): Promise<void> {
  if (!ticket.userId) {
    logger.warn("No userId for ticket, cannot send notification");
    return;
  }

  // Get user data to check notification preferences
  const userData = await getUserData(ticket.userId);
  const notificationsEnabled = userData?.notifications_enabled !== false;

  // Check if we should send this notification
  const shouldSend = await shouldSendPushNotification(
    ticket.userId,
    undefined, // no chatRoomId for support messages
    "support_message",
    notificationsEnabled
  );

  if (!shouldSend) {
    logger.info(`Skipping notification for user ${ticket.userId}`);
    return;
  }

  const truncatedContent = message.content.length > 100 ?
    message.content.substring(0, 97) + "..." :
    message.content;

  const notificationData: Record<string, string> = {
    type: "support_message",
    ticketId: ticket.id || "",
    ticketNumber: ticket.ticketNumber || "",
  };

  try {
    await sendFCMToUser(
      ticket.userId,
      {
        title: `Support Reply - ${ticket.ticketNumber || "Ticket"}`,
        body: truncatedContent,
      },
      notificationData
    );

    logger.info(`Sent push notification to user ${ticket.userId}`);
  } catch (error) {
    logger.error(`Failed to send notification to ${ticket.userId}:`, error);
  }
}

// ============================================================================
// Cloud Function: onTicketStatusChange
// ============================================================================

/**
 * Triggered when a ticket is updated.
 * Handles status change notifications.
 */
export const onTicketUpdate = onDocumentUpdated(
  {
    document: `${TICKETS_COLLECTION}/{ticketId}`,
    database: "green-hive-db",
  },
  async (event) => {
    const ticketId = event.params.ticketId;
    const beforeData = event.data?.before.data() as SupportTicket | undefined;
    const afterData = event.data?.after.data() as SupportTicket | undefined;

    if (!beforeData || !afterData) return;

    // Check if status changed
    if (beforeData.status !== afterData.status) {
      logger.info(`Ticket ${ticketId} status changed: ${beforeData.status} -> ${afterData.status}`);

      // Create system message for status change
      const statusMessage = getStatusChangeMessage(beforeData.status, afterData.status);
      await createSystemMessage(ticketId, statusMessage, "status_change");

      // Notify user of status change
      if (afterData.userId) {
        await sendStatusChangeNotification(afterData, beforeData.status, afterData.status);
      }
    }
  }
);

/**
 * Generate message for status change
 */
function getStatusChangeMessage(oldStatus: string, newStatus: string): string {
  const statusMessages: Record<string, string> = {
    in_review: "Your ticket is now being reviewed by our support team.",
    in_progress: "Our team is actively working on your request.",
    resolved: "Your ticket has been resolved. If you need further assistance, please reply to this ticket.",
    closed: "This ticket has been closed. Thank you for contacting support.",
    on_hold: "Your ticket is currently on hold pending additional information.",
  };

  return statusMessages[newStatus] || `Ticket status updated to ${newStatus.replace("_", " ")}.`;
}

/**
 * Send notification for status change
 */
async function sendStatusChangeNotification(
  ticket: SupportTicket,
  oldStatus: string,
  newStatus: string
): Promise<void> {
  // Get user data to check notification preferences
  const userData = await getUserData(ticket.userId);
  const notificationsEnabled = userData?.notifications_enabled !== false;

  // Check if we should send this notification
  const shouldSend = await shouldSendPushNotification(
    ticket.userId,
    undefined, // no chatRoomId for status changes
    "support_status_change",
    notificationsEnabled
  );

  if (!shouldSend) {
    logger.info(`Skipping status change notification for user ${ticket.userId}`);
    return;
  }

  const notificationData: Record<string, string> = {
    type: "support_status_change",
    ticketId: ticket.id || "",
    ticketNumber: ticket.ticketNumber || "",
    newStatus,
  };

  const title = `Ticket ${ticket.ticketNumber || ""} Updated`;
  const body = getStatusChangeMessage(oldStatus, newStatus);

  try {
    await sendFCMToUser(
      ticket.userId,
      {title, body},
      notificationData
    );
    logger.info(`Sent status change notification to ${ticket.userId}`);
  } catch (error) {
    logger.error("Failed to send status notification:", error);
  }
}

// ============================================================================
// Cloud Function: Auto-close Resolved Tickets
// ============================================================================

/**
 * Scheduled function to auto-close resolved tickets after 7 days.
 * Runs daily at 2:00 AM UTC.
 */
export const autoCloseResolvedTickets = onSchedule(
  {
    schedule: "0 2 * * *", // Daily at 2 AM UTC
    timeZone: "UTC",
    retryCount: 3,
  },
  async () => {
    logger.info("Starting auto-close job for resolved tickets");

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    try {
      // Find resolved tickets older than 7 days
      const snapshot = await db
        .collection(TICKETS_COLLECTION)
        .where("status", "==", "resolved")
        .where("updatedAt", "<=", Timestamp.fromDate(sevenDaysAgo))
        .limit(100) // Process in batches
        .get();

      if (snapshot.empty) {
        logger.info("No tickets to auto-close");
        return;
      }

      logger.info(`Found ${snapshot.size} tickets to auto-close`);

      const batch = db.batch();
      const ticketIds: string[] = [];

      for (const doc of snapshot.docs) {
        const ticketRef = db.collection(TICKETS_COLLECTION).doc(doc.id);

        batch.update(ticketRef, {
          status: "closed",
          updatedAt: FieldValue.serverTimestamp(),
          closedAt: FieldValue.serverTimestamp(),
        });

        ticketIds.push(doc.id);
      }

      await batch.commit();

      // Create system messages for each closed ticket
      for (const ticketId of ticketIds) {
        await createSystemMessage(
          ticketId,
          "This ticket has been automatically closed after 7 days of inactivity. If you need further assistance, please create a new ticket.",
          "ticketClosed"
        );
      }

      logger.info(`Auto-closed ${ticketIds.length} tickets`, {ticketIds});
    } catch (error) {
      logger.error("Error in auto-close job:", error);
    }
  }
);
