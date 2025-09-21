const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { StreamChat } = require("stream-chat");

admin.initializeApp();

// Environment variables for Stream API keys
const streamApiKey = functions.config().stream.api_key;
const streamApiSecret = functions.config().stream.api_secret;

// Initialize Stream Chat client
const serverClient = StreamChat.getInstance(streamApiKey, streamApiSecret);

/**
 * Calculates a compatibility score between two users based on their quiz answers.
 * The score is the number of answers they have in common.
 */
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
  const db = admin.firestore();
  const usersSnapshot = await db.collection("users").where("quiz_completed", "==", true).get();
  const allUsers = usersSnapshot.docs.map(doc => ({ uid: doc.id, ...doc.data() }));

  const usersBySector = allUsers.reduce((acc, user) => {
    const sector = user.sector;
    if (sector) {
      if (!acc[sector]) {
        acc[sector] = [];
      }
      acc[sector].push(user);
    }
    return acc;
  }, {});

  const groups = [];

  for (const sector in usersBySector) {
    let sectorUsers = usersBySector[sector];

    while (sectorUsers.length >= 5) {
      const groupLeader = sectorUsers.shift();
      
      // --- OPTIMIZATION: Find top 4 without sorting the whole list ---
      let top4 = [];
      for (const user of sectorUsers) {
        const compatibility = calculateCompatibility(groupLeader, user);
        // Add user if we don't have 4 yet
        if (top4.length < 4) {
          top4.push({ user, compatibility });
          top4.sort((a, b) => a.compatibility - b.compatibility); // Keep sorted
        } else if (compatibility > top4[0].compatibility) {
          // If user is more compatible than the least compatible in top4
          top4.shift(); // Remove the least compatible
          top4.push({ user, compatibility });
          top4.sort((a, b) => a.compatibility - b.compatibility); // Keep sorted
        }
      }
      const bestGroupUsers = top4.map(item => item.user);
      // --- END OPTIMIZATION ---
      
      const bestGroup = [groupLeader, ...bestGroupUsers];
      
      // Remove the users that were just grouped
      const groupedUserIds = new Set(bestGroup.map(u => u.uid));
      sectorUsers = sectorUsers.filter(u => !groupedUserIds.has(u.uid));
      
      const mergedInterests = [...new Set(bestGroup.flatMap(user => (user.personality && Array.isArray(user.personality.interests)) ? user.personality.interests : []))];
      
      const groupDocRef = db.collection("groups").doc();
      const groupId = groupDocRef.id;

      await groupDocRef.set({
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        status: "active",
        sector: sector,
        matched_on: {
          criteria: "quiz+location",
          interests: mergedInterests,
        },
        user_ids: bestGroup.map(user => user.uid),
        channel_id: groupId, // Use the Firestore doc ID as the channel ID
      });

      // Create Stream channel
      const channel = serverClient.channel('messaging', groupId, {
        name: `Group in ${sector}`,
        created_by_id: groupLeader.uid,
        members: bestGroup.map(user => user.uid),
      });
      await channel.create();

      groups.push({ id: groupId });

      functions.logger.info(`Created a new group ${groupId} for sector ${sector}.`);
    }
  }

  return { message: "Group creation process finished.", groupsCreated: groups.length };
});

exports.getStreamUserToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
  }
  const uid = context.auth.uid;
  try {
    const token = serverClient.createToken(uid);
    return { token };
  } catch (err) {
    console.error(`Error creating Stream token for user ${uid}:`, err);
    throw new functions.https.HttpsError("internal", "Could not create Stream token.");
  }
});
