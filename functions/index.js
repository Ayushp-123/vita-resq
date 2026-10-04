const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

function getHaversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) *
      Math.cos(lat2 * (Math.PI / 180)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Triggered on creation or when currentRadiusMeters expands
exports.onEmergencyUpdated = functions.firestore
  .document("emergencies/{emergencyId}")
  .onWrite(async (change, context) => {
    if (!change.after.exists) return;

    const emergency = change.after.data();
    if (emergency.status !== "SEARCHING") return;

    const victimLat = emergency.latitude;
    const victimLon = emergency.longitude;
    const victimId = emergency.victimId;
    const currentRadius = emergency.currentRadiusMeters || 500;
    const notifiedUserIds = emergency.notifiedUserIds || [];

    const usersSnapshot = await admin.firestore().collection("users").get();
    const notificationPromises = [];
    const newlyNotifiedIds = [];

    usersSnapshot.forEach((doc) => {
      const user = doc.data();
      const userId = doc.id;
      
      // Skip victim, offline users, or already notified users (Deduplication)
      if (userId === victimId || !user.isOnline || !user.fcmToken || notifiedUserIds.includes(userId)) return;

      const distance = getHaversineDistance(
        victimLat,
        victimLon,
        user.latitude,
        user.longitude
      );

      // Check current expanding radius stage
      if (distance <= currentRadius) {
        newlyNotifiedIds.push(userId);

        const payload = {
          notification: {
            title: "🚨 VITA RESQ EMERGENCY",
            body: `Someone nearby needs assistance.\nDistance: ${Math.round(distance)} m`,
          },
          data: {
            emergencyId: context.params.emergencyId,
            distanceMeters: String(Math.round(distance)),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          token: user.fcmToken,
        };

        notificationPromises.push(admin.messaging().send(payload));
      }
    });

    if (newlyNotifiedIds.length > 0) {
      await change.after.ref.update({
        notifiedUserIds: admin.firestore.FieldValue.arrayUnion(...newlyNotifiedIds),
      });
    }

    await Promise.all(notificationPromises);
  });
