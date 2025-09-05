
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

admin.initializeApp();
const firestore = admin.firestore();

/**
 * Ghép đôi người dùng khi có người mới vào hàng đợi.
 */
export const findMatch = onDocumentCreated(
  {document: "waiting_pool/{userId}", region: "asia-southeast1"},
  async (event) => {
    // ... (existing findMatch logic) ...
    logger.info(`[findMatch] Triggered by user: ${event.params.userId}`);

    const matchmakingLockRef = firestore.doc("locks/matchmaking_lock");

    try {
      await firestore.runTransaction(async (transaction) => {
        const matchmakingLock = await transaction.get(matchmakingLockRef);

        if (matchmakingLock.exists) {
          logger.info("[findMatch] Matchmaking is locked. Exiting.");
          return;
        }

        transaction.set(matchmakingLockRef, {
          lockedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const pool = await transaction.get(
          firestore.collection("waiting_pool")
        );

        if (pool.size < 2) {
          logger.info("[findMatch] Not enough users. Unlocking.");
          transaction.delete(matchmakingLockRef);
          return;
        }

        logger.info(`[findMatch] Found ${pool.size} users. Creating a match.`);

        const usersToMatch = pool.docs.slice(0, 2);
        const user1Id = usersToMatch[0].id;
        const user2Id = usersToMatch[1].id;

        const channelId = [user1Id, user2Id].sort().join("_");
        const callRef = firestore.collection("calls").doc(channelId);

        logger.info(`[findMatch] Matching ${user1Id} and ${user2Id}`);

        transaction.set(callRef, {
          channelId: channelId,
          participants: [user1Id, user2Id],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          status: "created",
        });

        transaction.delete(usersToMatch[0].ref);
        transaction.delete(usersToMatch[1].ref);
        transaction.delete(matchmakingLockRef);

        logger.info("[findMatch] Match created and unlocked successfully.");
      });
    } catch (error) {
      logger.error("[findMatch] Transaction failed: ", error);
      await matchmakingLockRef.delete().catch((e) => {
        logger.error("Failed to release lock on error: ", e);
      });
    }
  });

/**
 * Gửi thông báo tái tương tác cho người dùng không hoạt động.
 */
export const sendReengagementNotifications = onSchedule(
  {schedule: "every day 09:00", timeZone: "UTC"},
  async () => {
    logger.info("[Re-engagement] Starting job.");

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    try {
      const inactiveUsersSnapshot = await firestore
        .collection("users")
        .where("lastSeen", "<", sevenDaysAgo)
        .get();

      if (inactiveUsersSnapshot.empty) {
        logger.info("[Re-engagement] No inactive users found.");
        return;
      }

      const messages: admin.messaging.Message[] = [];
      inactiveUsersSnapshot.forEach((doc) => {
        const user = doc.data();
        if (user.fcmToken) {
          logger.info(`[Re-engagement] Found inactive user: ${doc.id}`);
          messages.push({
            token: user.fcmToken,
            notification: {
              title: "👋 We miss you!",
              body: "Come back and connect with someone new!",
            },
            data: {
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              screen: "/home",
            },
          });
        }
      });

      if (messages.length > 0) {
        const response = await admin.messaging().sendEach(messages);
        logger.info(
          `[Re-engagement] Sent ${response.successCount} messages successfully.`
        );
        if (response.failureCount > 0) {
          logger.warn(
            `[Re-engagement] Failed to send ${response.failureCount} messages.`
          );
        }
      }
    } catch (error) {
      logger.error("[Re-engagement] Error finding inactive users: ", error);
    }
  }
);
