const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { StreamChat } = require("stream-chat");

admin.initializeApp();

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

function calculateCompatibility(user1, user2) {
    if (!user1.personality || !user1.personality.answers || !user2.personality || !user2.personality.answers) {
        return 0;
    }
    const answers1 = user1.personality.answers;
    const answers2 = user2.personality.answers;
    let commonAnswers = 0;
    for (const key in answers1) {
        if (answers1.hasOwnProperty(key) && answers2.hasOwnProperty(key)) {
            if (answers1[key] === answers2[key]) {
                commonAnswers++;
            }
        }
    }
    return commonAnswers;
}

exports.createGroups = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }
    const uid = context.auth.uid;
    const db = admin.firestore();
    const streamClient = getStreamClient();

    if (!streamClient) {
        throw new functions.https.HttpsError("internal", "Stream client is not available due to missing configuration.");
    }

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
        throw new functions.https.HttpsError("not-found", "User record not found.");
    }
    const currentUser = { uid, ...userDoc.data() };

    if (currentUser.groupId) {
        functions.logger.info(`User ${uid} is already in group ${currentUser.groupId}.`);
        return { status: 'already_in_group', groupId: currentUser.groupId };
    }

    const sector = currentUser.sector;
    if (!sector) {
        throw new functions.https.HttpsError("failed-precondition", "User does not have a sector set.");
    }

    const availableUsersSnapshot = await db.collection("users")
        .where("sector", "==", sector)
        .where("quiz_completed", "==", true)
        .get();

    const trulyAvailableMates = availableUsersSnapshot.docs
        .map(doc => ({ uid: doc.id, ...doc.data() }))
        .filter(user => !user.groupId && user.uid !== uid);

    if (trulyAvailableMates.length === 0) {
        functions.logger.info(`No available users in sector ${sector} to form a group.`);
        await userRef.update({ matching_status: 'no_mates_available' });
        return { status: 'no_mates_available', message: "Sorry, there aren't enough bitemates in your area to form a group yet." };
    }

    let groupUsers = [];
    let matchStatus = '';

    // Tier 1: Perfect Match (group of 5)
    if (trulyAvailableMates.length >= 4) {
        let top4 = [];
        for (const user of trulyAvailableMates) {
            const compatibility = calculateCompatibility(currentUser, user);
            if (top4.length < 4) {
                top4.push({ user, compatibility });
                top4.sort((a, b) => a.compatibility - b.compatibility);
            } else if (compatibility > top4[0].compatibility) {
                top4.shift();
                top4.push({ user, compatibility });
                top4.sort((a, b) => a.compatibility - b.compatibility);
            }
        }
        groupUsers = top4.map(item => item.user);
        matchStatus = 'matched_perfect';
    } 
    // Tier 2: Partial Match (group of 2-4)
    else {
        groupUsers = trulyAvailableMates;
        matchStatus = 'matched_partial';
    }

    const newGroup = [currentUser, ...groupUsers];
    const newUserIds = newGroup.map(u => u.uid);

    const groupDocRef = db.collection("groups").doc();
    const groupId = groupDocRef.id;

    await groupDocRef.set({
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        status: "active",
        sector: sector,
        user_ids: newUserIds,
        channel_id: groupId,
    });

    const channel = streamClient.channel('messaging', groupId, {
        name: `BiteMates Group in ${sector}`,
        created_by_id: uid,
        members: newUserIds,
    });
    await channel.create();

    const batch = db.batch();
    newUserIds.forEach(userId => {
        const userRef = db.collection("users").doc(userId);
        batch.update(userRef, { groupId: groupId, matching_status: 'matched' });
    });
    await batch.commit();

    functions.logger.info(`Created new group ${groupId} for sector ${sector}. Status: ${matchStatus}`);

    return { status: matchStatus, groupId: groupId };
});

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

      if (!groupDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Group not found.");
      }

      const groupData = groupDoc.data();
      const userIds = groupData.user_ids || [];

      if (!userIds.includes(uid)) {
        throw new functions.https.HttpsError("permission-denied", "You are not a member of this group.");
      }

      const updatedUserIds = userIds.filter(id => id !== uid);

      if (updatedUserIds.length === 0) {
        // If the group is empty, delete it
        transaction.delete(groupRef);
      } else {
        // Otherwise, update the user list
        transaction.update(groupRef, { user_ids: updatedUserIds });
      }

      // Remove the groupId from the user's profile
      transaction.update(userRef, { groupId: admin.firestore.FieldValue.delete() });
    });

    functions.logger.info(`User ${uid} successfully left group ${groupId}.`);
    return { status: "success" };

  } catch (error) {
    functions.logger.error(`Error leaving group ${groupId} for user ${uid}:`, error);
    throw new functions.https.HttpsError("internal", "Could not leave group.", error);
  }
});

exports.stayAndDine = functions.https.onCall(async (data, context) => {
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

  try {
    let status = 'waiting_for_more';

    await db.runTransaction(async (transaction) => {
      const groupDoc = await transaction.get(groupRef);

      if (!groupDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Group not found.");
      }

      const groupData = groupDoc.data();
      const stayAndDineUsers = groupData.stay_and_dine_users || [];

      if (!stayAndDineUsers.includes(uid)) {
        stayAndDineUsers.push(uid);
        transaction.update(groupRef, { stay_and_dine_users: stayAndDineUsers });
      }

      if (stayAndDineUsers.length >= 2) {
        transaction.update(groupRef, { status: 'dinner_planned' });
        status = 'dinner_planned';
      }
    });

    return { status };

  } catch (error) {
    functions.logger.error(`Error with stayAndDine for group ${groupId} and user ${uid}:`, error);
    throw new functions.https.HttpsError("internal", "Could not process stay and dine request.", error);
  }
});

exports.addConnection = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
  }

  const uid = context.auth.uid;
  const { otherUserId } = data;

  if (!otherUserId) {
    throw new functions.https.HttpsError("invalid-argument", "The function must be called with a 'otherUserId'.");
  }

  const db = admin.firestore();
  const currentUserRef = db.collection("users").doc(uid);
  const otherUserRef = db.collection("users").doc(otherUserId);

  try {
    await db.runTransaction(async (transaction) => {
      transaction.update(currentUserRef, {
        connections: admin.firestore.FieldValue.arrayUnion(otherUserId),
      });
      transaction.update(otherUserRef, {
        connections: admin.firestore.FieldValue.arrayUnion(uid),
      });
    });

    functions.logger.info(`User ${uid} and ${otherUserId} are now connected.`);
    return { status: "success" };

  } catch (error) {
    functions.logger.error(`Error adding connection between ${uid} and ${otherUserId}:`, error);
    throw new functions.https.HttpsError("internal", "Could not add connection.", error);
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
