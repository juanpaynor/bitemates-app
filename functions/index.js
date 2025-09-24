const functions = require("firebase-functions");
const { StreamChat } = require("stream-chat");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// This function remains for potential future direct messaging features.
const getStreamToken = functions.runWith({ secrets: ["STREAM_API_KEY", "STREAM_API_SECRET"] }).https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }
    try {
        const apiKey = process.env.STREAM_API_KEY;
        const apiSecret = process.env.STREAM_API_SECRET;
        const serverClient = StreamChat.getInstance(apiKey, apiSecret);
        const token = serverClient.createToken(context.auth.uid);
        return { token: token };
    } catch (error) {
        console.error(`Error creating Stream token for user ${context.auth.uid}:`, error);
        throw new functions.https.HttpsError("internal", "An error occurred while creating the Stream token.");
    }
});

// This function securely provides a token for a specific group chat after verifying membership.
const getGroupChatToken = functions.runWith({ secrets: ["STREAM_API_KEY", "STREAM_API_SECRET"] }).https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }
    const userId = context.auth.uid;
    const groupId = data.groupId;
    if (!groupId) {
        throw new functions.https.HttpsError("invalid-argument", "The function must be called with a 'groupId'.");
    }

    try {
        const groupDoc = await db.collection("groups").doc(groupId).get();
        if (!groupDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Group not found.");
        }
        const groupData = groupDoc.data();
        const groupMembers = groupData.members || [];
        if (!groupMembers.includes(userId)) {
            throw new functions.https.HttpsError("permission-denied", "User is not a member of this group.");
        }

        const apiKey = process.env.STREAM_API_KEY;
        const apiSecret = process.env.STREAM_API_SECRET;
        const serverClient = StreamChat.getInstance(apiKey, apiSecret);

        const channel = serverClient.channel("messaging", groupId, {
            name: groupData.name || "Unnamed Group",
            created_by_id: userId, 
            members: groupMembers, 
        });
        await channel.create();

        const token = serverClient.createToken(userId);

        return { token: token };

    } catch (error) {
        console.error(`Error processing group chat token for user ${userId} and group ${groupId}:`, error);
        if (error instanceof functions.https.HttpsError) {
            throw error; 
        } 
        throw new functions.https.HttpsError("internal", "An unexpected error occurred.");
    }
});


// Hybrid matching function with ideal logic and a developer fallback.
const createGroups = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const currentUserId = context.auth.uid;
    const GROUP_SIZE = 5;

    // --- Part 1: Ideal Matching Logic ---
    let groupFormedForCurrentUser = false;

    const waitingUsersSnapshot = await db.collection('users').where('isWaitingForGroup', '==', true).get();

    if (waitingUsersSnapshot.docs.length >= GROUP_SIZE) {
        const waitingUsers = waitingUsersSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

        const userGroups = waitingUsers.reduce((acc, user) => {
            const personality = user.quizResult || 'unknown';
            const location = user.locationSector || 'unknown';
            const key = `${personality}_${location}`;
            if (!acc[key]) acc[key] = [];
            acc[key].push(user);
            return acc;
        }, {});

        for (const key in userGroups) {
            if (userGroups[key].length >= GROUP_SIZE) {
                const groupMembers = userGroups[key].slice(0, GROUP_SIZE);
                const memberIds = groupMembers.map(user => user.id);
                
                if (memberIds.includes(currentUserId)) {
                    groupFormedForCurrentUser = true;
                }

                const groupRef = db.collection('groups').doc();
                const batch = db.batch();

                batch.set(groupRef, {
                    name: `BiteMates (${groupMembers[0].quizResult || 'Mixed'})`,
                    members: memberIds, // Security: This is the crucial step
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                for (const member of groupMembers) {
                    const userRef = db.collection('users').doc(member.id);
                    batch.update(userRef, { groupId: groupRef.id, isWaitingForGroup: false, groupAssigned: true });
                }
                await batch.commit();
                break; 
            }
        }
    }

    // --- Part 2: Developer Fallback Logic ---
    const currentUserDoc = await db.collection('users').doc(currentUserId).get();
    const isCurrentUserStillWaiting = currentUserDoc.exists && currentUserDoc.data().isWaitingForGroup;

    if (isCurrentUserStillWaiting) {
        const buddySnapshot = await db.collection('users')
            .where('groupAssigned', '==', false)
            .where(admin.firestore.FieldPath.documentId(), '!=', currentUserId)
            .limit(GROUP_SIZE - 1)
            .get();

        if (buddySnapshot.docs.length === GROUP_SIZE - 1) {
            const groupMembers = [
                { id: currentUserId, ...currentUserDoc.data() },
                ...buddySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }))
            ];
            const memberIds = groupMembers.map(user => user.id);

            const groupRef = db.collection('groups').doc();
            const batch = db.batch();

            batch.set(groupRef, {
                name: "Dev Test Group",
                members: memberIds, // Security: This is the crucial step
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            for (const member of groupMembers) {
                const userRef = db.collection('users').doc(member.id);
                batch.update(userRef, { groupId: groupRef.id, isWaitingForGroup: false, groupAssigned: true });
            }
            await batch.commit();
            groupFormedForCurrentUser = true;
        }
    }
    
    if(groupFormedForCurrentUser){
        return { status: 'Group successfully formed for the current user.' };
    } else {
        return { status: 'Not enough users for ideal matching, and could not form a developer fallback group.' };
    }
});

module.exports = {
    getStreamToken,
    getGroupChatToken,
    createGroups,
};
