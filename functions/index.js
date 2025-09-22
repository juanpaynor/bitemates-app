const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { StreamChat } = require("stream-chat");

admin.initializeApp();

// --- Stream Chat Client Initialization ---
const streamApiKey = functions.config().stream.api_key;
const streamApiSecret = functions.config().stream.api_secret;
let serverClient;

function getStreamClient() {
  if (!serverClient) {
    if (streamApiKey && streamApiSecret) {
      serverClient = StreamChat.getInstance(streamApiKey, streamApiSecret);
    } else {
      functions.logger.error("Stream API key or secret is not configured.");
    }
  }
  return serverClient;
}

// --- Compatibility Calculation ---
function calculateCompatibility(user1, user2) {
    const p1 = user1.personality;
    const p2 = user2.personality;
    if (!p1 || !p2) return 0;

    let score = 0;
    const MAX_SCORE_PER_TRAIT = 10;

    if (typeof p1.extraversion === 'number' && typeof p2.extraversion === 'number') {
        const diff = Math.abs(p1.extraversion - p2.extraversion);
        score += Math.max(0, MAX_SCORE_PER_TRAIT - (diff * 2));
    }
    if (typeof p1.openness === 'number' && typeof p2.openness === 'number') {
        const diff = Math.abs(p1.openness - p2.openness);
        score += Math.max(0, MAX_SCORE_PER_TRAIT - (diff * 2.5));
    }
    if (typeof p1.chill_factor === 'number' && typeof p2.chill_factor === 'number') {
        const diff = Math.abs(p1.chill_factor - p2.chill_factor);
        score += Math.max(0, MAX_SCORE_PER_TRAIT - (diff * 2.5));
    }
    if (p1.conversation_style && p1.conversation_style === p2.conversation_style) {
        score += 15;
    }
    if (Array.isArray(p1.interests) && Array.isArray(p2.interests)) {
        const commonInterests = p1.interests.filter(interest => p2.interests.includes(interest));
        score += commonInterests.length * 10;
    }
    return Math.round(score);
}

// --- Group Creation and Finalization ---
async function finalizeGroup(db, streamClient, users, sector, matchTier) {
    const userIds = users.map(u => u.uid);
    const groupDocRef = db.collection("groups").doc();
    const groupId = groupDocRef.id;

    await groupDocRef.set({
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        status: "active",
        sector: sector,
        user_ids: userIds,
        channel_id: groupId,
        match_tier: matchTier,
    });

    const channel = streamClient.channel('messaging', groupId, {
        name: `BiteMates Group in ${sector}`,
        created_by_id: users[0].uid,
        members: userIds,
    });
    await channel.create();

    const batch = db.batch();
    userIds.forEach(userId => {
        const userRef = db.collection("users").doc(userId);
        batch.update(userRef, {
            groupId: groupId,
            matching_status: 'matched',
            matching_started_at: admin.firestore.FieldValue.delete(), // Clean up timestamp
        });
    });
    await batch.commit();

    functions.logger.info(`SUCCESS: Tier '${matchTier}' group ${groupId} created for sector ${sector}.`);
    return { status: 'matched', groupId: groupId };
}

// --- Main Matching Function ---
exports.createGroups = functions.runWith({ timeoutSeconds: 120 }).https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const uid = context.auth.uid;
    const db = admin.firestore();
    const streamClient = getStreamClient();
    if (!streamClient) {
        throw new functions.https.HttpsError("internal", "Stream client is not configured.");
    }

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User record not found.");
    
    const currentUser = { uid, ...userDoc.data() };
    if (currentUser.groupId) return { status: 'already_in_group', groupId: currentUser.groupId };
    if (!currentUser.sector) throw new functions.https.HttpsError("failed-precondition", "User does not have a sector set.");

    // --- Enter the Matching Pool ---
    await userRef.update({
        matching_status: 'searching',
        matching_started_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Give the system a moment for other users to join the pool.
    // This helps increase the chances of forming a larger group on the first try.
    await new Promise(resolve => setTimeout(resolve, 3000));

    const searchingUsersSnapshot = await db.collection("users")
        .where("quiz_completed", "==", true)
        .where("matching_status", "==", "searching")
        .get();

    let pool = searchingUsersSnapshot.docs.map(doc => ({ uid: doc.id, ...doc.data() }));
    
    if (pool.length < 2) {
        functions.logger.info(`User ${uid} is searching, but pool size is too small (${pool.length}). Waiting.`);
        return { status: 'searching' };
    }

    // Add compatibility scores to each user relative to the current user
    pool.forEach(user => {
        user.compatibility = (user.uid === uid) ? 1000 : calculateCompatibility(currentUser, user);
    });
    pool.sort((a, b) => b.compatibility - a.compatibility);

    const adjacentSectors = {
        'southies': ['middle'],
        'middle': ['southies', 'northies'],
        'northies': ['middle']
    };

    // --- Tier 1: Perfect Match (Same Sector, High Compatibility) ---
    const sameSectorPool = pool.filter(u => u.sector === currentUser.sector);
    if (sameSectorPool.length >= 5) {
        const group = sameSectorPool.slice(0, 5);
        return await finalizeGroup(db, streamClient, group, currentUser.sector, 'perfect');
    }

    // --- Tier 2: Expanded Match (Adjacent Sectors) ---
    const relevantSectors = [currentUser.sector, ...(adjacentSectors[currentUser.sector] || [])];
    const expandedPool = pool.filter(u => relevantSectors.includes(u.sector));
    if (expandedPool.length >= 5) {
        const group = expandedPool.slice(0, 5);
        return await finalizeGroup(db, streamClient, group, currentUser.sector, 'expanded_5');
    }
    if (expandedPool.length >= 3) {
        const group = expandedPool.slice(0, 3);
        return await finalizeGroup(db, streamClient, group, currentUser.sector, 'expanded_3');
    }

    // --- Tier 3: Guaranteed Match (Last Resort) ---
    // If the user has been waiting for a while (e.g., 90 seconds), form the best possible group of 2.
    const userWaitTime = Date.now() - (currentUser.matching_started_at?.toDate()?.getTime() || Date.now());
    if (pool.length >= 2 && userWaitTime > 90000) {
        const group = pool.slice(0, 2); // The pool is already sorted by compatibility
        return await finalizeGroup(db, streamClient, group, currentUser.sector, 'guaranteed_2');
    }

    // --- If no criteria met, remain in the pool ---
    functions.logger.info(`No suitable group found for ${uid} yet. Remaining in pool.`);
    return { status: 'searching' };
});


// --- Other Functions (Unchanged) ---
exports.leaveGroup = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
  }
  const uid = context.auth.uid;
  const { groupId } = data;
  if (!groupId) {
    throw new functions.https.HttpsError("invalid-argument", "The function must be called with a 'groupId'.");
  }
  const db = admin.firestore();
  const groupRef = db.collection("groups").doc(groupId);
  const userRef = db.collection("users").doc(uid);
  try {
    await db.runTransaction(async (transaction) => {
      const groupDoc = await transaction.get(groupRef);
      if (!groupDoc.exists) throw new functions.https.HttpsError("not-found", "Group not found.");
      const groupData = groupDoc.data();
      const userIds = groupData.user_ids || [];
      if (!userIds.includes(uid)) throw new functions.https.HttpsError("permission-denied", "You are not a member of this group.");
      const updatedUserIds = userIds.filter(id => id !== uid);
      if (updatedUserIds.length === 0) {
        transaction.delete(groupRef);
      } else {
        transaction.update(groupRef, { user_ids: updatedUserIds });
      }
      transaction.update(userRef, { groupId: admin.firestore.FieldValue.delete() });
    });
    functions.logger.info(`User ${uid} successfully left group ${groupId}.`);
    return { status: "success" };
  } catch (error) {
    functions.logger.error(`Error leaving group ${groupId} for user ${uid}:`, error);
    throw new functions.https.HttpsError("internal", "Could not leave group.", error);
  }
});

exports.getStreamUserToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
  }
  const uid = context.auth.uid;
  const streamClient = getStreamClient(); 
  if (!streamClient) {
      throw new functions.https.HttpsError("internal", "Stream client is not available due to missing configuration.");
  }
  try {
    const token = streamClient.createToken(uid);
    return { token };
  } catch (err) {
    console.error(`Error creating Stream token for user ${uid}:`, err);
    throw new functions.https.HttpsError("internal", "Could not create Stream token.");
  }
});
