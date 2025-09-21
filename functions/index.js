
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

// Helper function to calculate compatibility score
const calculateCompatibility = (user1, user2) => {
  const interestOverlap = user1.interests.filter(interest => user2.interests.includes(interest)).length;
  const extraversionDifference = Math.abs(user1.extraversion - user2.extraversion);
  const chillFactorDifference = Math.abs(user1.chill_factor - user2.chill_factor);

  // You can tweak these weights
  return (interestOverlap * 10) - (extraversionDifference * 2) - (chillFactorDifference * 2);
};

exports.createGroups = functions.https.onRequest(async (req, res) => {
  try {
    const usersSnapshot = await db.collection("users").get();
    const allUsers = usersSnapshot.docs.map(doc => ({ uid: doc.id, ...doc.data() }));

    const usersBySector = allUsers.reduce((acc, user) => {
      (acc[user.sector] = acc[user.sector] || []).push(user);
      return acc;
    }, {});

    const groups = [];

    // Grouping logic for each sector
    for (const sector in usersBySector) {
      let sectorUsers = [...usersBySector[sector]];

      while (sectorUsers.length >= 5) {
        // Find the best group of 5
        let bestGroup = [];
        let bestScore = -Infinity;

        // This is a simplified approach. A more sophisticated algorithm could be used here.
        // For now, we'll take the first user and find their 4 most compatible matches.
        let groupLeader = sectorUsers.shift();
        sectorUsers.sort((a, b) => calculateCompatibility(groupLeader, b) - calculateCompatibility(groupLeader, a));
        
        bestGroup = [groupLeader, ...sectorUsers.splice(0, 4)];

        const mergedInterests = [...new Set(bestGroup.flatMap(user => user.interests))];

        groups.push({
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          status: "active",
          sector: sector,
          matched_on: {
            criteria: "quiz+location",
            interests: mergedInterests,
          },
          user_ids: bestGroup.map(user => user.uid),
        });
      }
    }
    
    // Create groups in Firestore
    const batch = db.batch();
    groups.forEach(group => {
      const groupRef = db.collection("groups").doc();
      batch.set(groupRef, group);
    });
    await batch.commit();

    res.status(200).send({ message: "Groups created successfully!", groupCount: groups.length });

  } catch (error) {
    console.error("Error creating groups:", error);
    res.status(500).send({ error: "Something went wrong." });
  }
});
