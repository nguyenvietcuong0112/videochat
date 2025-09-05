
console.log("Function cold start: Initializing...");

const functions = require("firebase-functions");
console.log("firebase-functions loaded.");

const admin = require("firebase-admin");
console.log("firebase-admin loaded.");

const { RtcTokenBuilder, RtcRole } = require("agora-token");
console.log("agora-token loaded.");

try {
  admin.initializeApp();
  console.log("Firebase Admin SDK initialized successfully.");
} catch (e) {
  console.error("CRITICAL: Failed to initialize Firebase Admin SDK", e);
}

let APP_ID;
let APP_CERTIFICATE;

try {
  APP_ID = functions.config().agora.app_id;
  APP_CERTIFICATE = functions.config().agora.app_cert;
  console.log("Agora config loaded successfully.");
  if (!APP_ID || !APP_CERTIFICATE) {
    console.error(
      "CRITICAL: Agora config loaded but app_id or app_cert is missing/empty."
    );
  }
} catch (e) {
  console.error(
    "CRITICAL: Failed to load Agora config from functions.config().agora",
    e
  );
}

// Function để tạo Agora Token
exports.generateAgoraToken = functions.https.onCall(async (data, context) => {
  console.log("generateAgoraToken function invoked.");

  if (!context.auth) {
    console.error("Authentication check failed: No context.auth.");
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const channelName = data.channelName;
  const uid = context.auth.uid; // uid của người dùng gọi hàm
  const role = RtcRole.PUBLISHER;
  const expirationTimeInSeconds = 3600;
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  if (!channelName) {
    console.error("Invalid argument: channelName is missing.");
    throw new functions.https.HttpsError(
      "invalid-argument",
      'The function must be called with "channelName".' // SỬA LỖI CÚ PHÁP
    );
  }

  try {
    console.log(`Building token for channel: ${channelName}, uid: ${uid}`);
    // UID trong token nên là 0 để bất kỳ ai có token đều có thể tham gia
    const token = RtcTokenBuilder.buildTokenWithUid(
      APP_ID,
      APP_CERTIFICATE,
      channelName,
      0, 
      role,
      privilegeExpiredTs
    );

    console.log(`Successfully generated token for channel: ${channelName}`);
    return { token: token };
  } catch (error) {
    console.error("Error generating Agora token:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Could not generate Agora token"
    );
  }
});

// Function để gửi thông báo cuộc gọi
exports.sendCallNotification = functions.https.onCall(async (data, context) => {
  console.log("sendCallNotification function invoked.");

  if (!context.auth) {
    console.error("Authentication check failed: No context.auth.");
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const callerId = context.auth.uid;
  const calleeId = data.calleeId;
  const channelName = data.channelName;

  if (!calleeId || !channelName) {
    console.error("Invalid arguments: calleeId or channelName is missing.");
    throw new functions.https.HttpsError(
      "invalid-argument",
      'The function must be called with "calleeId" and "channelName".' // SỬA LỖI CÚ PHÁP
    );
  }

  try {
    const db = admin.firestore();

    // 1. Lấy thông tin người được gọi (callee) để có fcmToken
    const calleeDoc = await db.collection("users").doc(calleeId).get();
    if (!calleeDoc.exists) {
      console.error(`Callee user document not found for uid: ${calleeId}`);
      throw new functions.https.HttpsError("not-found", "Callee user not found.");
    }
    const calleeData = calleeDoc.data();
    const fcmToken = calleeData.fcmToken;

    if (!fcmToken) {
      console.error(`FCM token not found for callee: ${calleeId}`);
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Callee does not have an FCM token."
      );
    }
    
    // 2. Lấy thông tin người gọi (caller) để hiển thị trên thông báo
     const callerDoc = await db.collection("users").doc(callerId).get();
     if (!callerDoc.exists) {
         throw new functions.https.HttpsError("not-found", "Caller user not found.");
     }
     const callerData = callerDoc.data();
     const callerName = callerData.displayName || "Someone";

    // 3. Tạo một Agora token mới cho người nhận cuộc gọi
    const expirationTimeInSeconds = 3600;
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;
    const callToken = RtcTokenBuilder.buildTokenWithUid(
        APP_ID,
        APP_CERTIFICATE,
        channelName,
        0, // uid = 0 để bất kỳ ai cũng có thể tham gia
        RtcRole.PUBLISHER,
        privilegeExpiredTs
    );

    // 4. Tạo payload cho data message
    const payload = {
      token: fcmToken, // Token của thiết bị nhận
      data: {
        type: "incoming_call",
        channelName: channelName,
        callerName: callerName,
        callerId: callerId,
        agoraToken: callToken, // Gửi token đã tạo cho người nhận
      },
      // Ưu tiên cao và thiết lập thời gian sống để đảm bảo gửi nhanh
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            alert: {
              title: "Incoming Call",
              body: `${callerName} is calling you.`,
            },
            sound: "default", 
            "content-available": 1, 
          },
        },
      },
       android: {
        priority: "high",
      },
    };

    // 5. Gửi thông báo
    console.log(`Sending call notification to callee: ${calleeId}`);
    await admin.messaging().send(payload);

    console.log("Successfully sent call notification.");
    return { success: true };

  } catch (error) {
    console.error("Error sending call notification:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Could not send call notification",
      error
    );
  }
});
