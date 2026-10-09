const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Calculates Haversine distance in meters between two coordinate pairs.
 */
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

/**
 * Cloud Function triggered on write to emergencies/{emergencyId}.
 * Dispatches high-importance FCM push notifications to nearby online responders
 * when:
 * 1. A new SEARCHING emergency is created.
 * 2. An emergency transitions into SEARCHING state.
 * 3. The search radius expands to include newly eligible responders.
 *
 * Safeguards:
 * - Exits immediately on routine writes (victim/responder GPS updates, status updates
 *   to ASSIGNED/APPROACHING/ARRIVED/COMPLETED/CANCELLED, or its own notifiedUserIds update).
 * - Excludes the victim from receiving their own alert.
 * - Deduplicates responders via notifiedUserIds array to prevent spam.
 * - Formats FCM payload with high-priority Android channel and emergencyId for direct app routing.
 */
exports.onEmergencyUpdated = functions.firestore
  .document("emergencies/{emergencyId}")
  .onWrite(async (change, context) => {
    // 1. Skip document deletions
    if (!change.after.exists) return;

    const after = change.after.data();

    // 2. Only active SEARCHING emergencies trigger responder dispatch
    if (after.status !== "SEARCHING") return;

    const isNew = !change.before.exists;
    const before = isNew ? null : change.before.data();

    const beforeRadius = before ? (before.currentRadiusMeters || 500) : 0;
    const afterRadius = after.currentRadiusMeters || 500;
    const isRadiusExpanded = before && afterRadius > beforeRadius;
    const isNewSearching = before && before.status !== "SEARCHING" && after.status === "SEARCHING";

    // 3. Prevent duplicate notifications on routine writes (GPS pings, deduplication writes, etc.)
    if (!isNew && !isRadiusExpanded && !isNewSearching) {
      return;
    }

    const victimLat = after.latitude;
    const victimLon = after.longitude;
    const victimId = after.victimId || after.userId;
    const currentRadius = afterRadius;
    const notifiedUserIds = Array.isArray(after.notifiedUserIds) ? after.notifiedUserIds : [];

    // Validate essential emergency coordinates and victim ID
    if (typeof victimLat !== "number" || typeof victimLon !== "number" || !victimId) {
      return;
    }

    // 4. Retrieve online users to evaluate proximity
    const usersSnapshot = await admin.firestore().collection("users").get();
    const notificationPromises = [];
    const newlyNotifiedIds = [];

    usersSnapshot.forEach((doc) => {
      const user = doc.data();
      const userId = doc.id;

      // Filter: Skip victim, offline users, users without FCM tokens, missing coordinates, or already notified
      if (
        userId === victimId ||
        !user.isOnline ||
        !user.fcmToken ||
        typeof user.latitude !== "number" ||
        typeof user.longitude !== "number" ||
        notifiedUserIds.includes(userId)
      ) {
        return;
      }

      const distance = getHaversineDistance(
        victimLat,
        victimLon,
        user.latitude,
        user.longitude
      );

      // Check if user is within the active geofenced radius stage
      if (distance <= currentRadius) {
        newlyNotifiedIds.push(userId);

        const emergencyType = String(after.type || "EMERGENCY");
        const distanceRounded = Math.round(distance);

        const payload = {
          notification: {
            title: "🚨 Vita ResQ — Emergency Nearby",
            body: `Someone nearby needs emergency assistance (${emergencyType}). Distance: ${distanceRounded} m`,
          },
          data: {
            emergencyId: context.params.emergencyId,
            type: emergencyType,
            distanceMeters: String(distanceRounded),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "vita_resq_emergency_alerts",
              priority: "high",
              defaultSound: true,
              defaultVibrateTimings: true,
            },
          },
          token: user.fcmToken,
        };

        notificationPromises.push(
          admin
            .messaging()
            .send(payload)
            .catch((err) => {
              console.warn(`Failed to dispatch FCM to user ${userId}:`, err.message);
            })
        );
      }
    });

    // 5. Atomic deduplication: record newly notified responder IDs in the emergency document
    if (newlyNotifiedIds.length > 0) {
      await change.after.ref.update({
        notifiedUserIds: admin.firestore.FieldValue.arrayUnion(...newlyNotifiedIds),
      });
    }

    // 6. Await all FCM dispatch operations
    await Promise.all(notificationPromises);
  });
