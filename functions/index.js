const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// 1️⃣ Chat Request Notification
exports.sendRequestNotification = functions.firestore
  .document("chat_requests/{requestId}")
  .onCreate(async (snap, context) => {
    const requestData = snap.data();
    const targetUid = requestData.targetUid;

    if (!targetUid) return null;

    // get target user's FCM token
    const targetDoc = await admin.firestore().collection("users").doc(targetUid).get();
    const token = targetDoc.data()?.fcmToken;

    if (!token) return null;

    const payload = {
      notification: {
        title: "New Chat Request",
        body: `${requestData.senderName} ने आपको रिक्वेस्ट भेजी है`,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      data: {
        screen: "incomingRequest",
        senderUid: requestData.senderUid,
      },
    };

    return admin.messaging().sendToDevice(token, payload);
  });

// 2️⃣ Chat Message Notification
exports.sendMessageNotification = functions.firestore
  .document("messages/{chatId}/{messageId}")
  .onCreate(async (snap, context) => {
    const msgData = snap.data();
    const targetUid = msgData.targetUid;

    if (!targetUid) return null;

    const targetDoc = await admin.firestore().collection("users").doc(targetUid).get();
    const token = targetDoc.data()?.fcmToken;

    if (!token) return null;

    const payload = {
      notification: {
        title: `New Message from ${msgData.senderName}`,
        body: msgData.text,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      data: {
        screen: "chatRoom",
        senderUid: msgData.senderUid,
        chatId: msgData.chatId,
      },
    };

    return admin.messaging().sendToDevice(token, payload);
  });
