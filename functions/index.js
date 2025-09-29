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
        
        if (!apiKey || !apiSecret) {
            throw new functions.https.HttpsError("internal", "Stream Chat credentials not configured.");
        }
        
        const serverClient = StreamChat.getInstance(apiKey, apiSecret);
        const token = serverClient.createToken(context.auth.uid);
        return { token: token };
    } catch (error) {
        console.error(`Error creating Stream token for user ${context.auth.uid}:`, error);
        throw new functions.https.HttpsError("internal", "An error occurred while creating the Stream token.");
    }
});

// Stream Chat integration with proper credentials
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

        // Get credentials from Firebase secrets
        const apiKey = process.env.STREAM_API_KEY;
        const apiSecret = process.env.STREAM_API_SECRET;
        
        if (!apiKey || !apiSecret) {
            console.error('Stream Chat credentials missing');
            throw new functions.https.HttpsError("internal", "Stream Chat not configured");
        }
        
        console.log('Creating Stream Chat token for user:', userId, 'in group:', groupId);

        // Initialize Stream Chat
        const serverClient = StreamChat.getInstance(apiKey, apiSecret);
        
        // Get user information for Stream Chat
        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data() || {};
        const userNickname = userData.nickname || userData.email || `User_${userId.substring(0, 8)}`;

        // Create/update user in Stream Chat
        await serverClient.upsertUser({
            id: userId,
            name: userNickname,
            image: userData.photoUrl || undefined,
        });

        // Create/get channel
        const channel = serverClient.channel("messaging", groupId, {
            name: groupData.name || "BiteMates Chat",
            created_by_id: userId,
            members: groupMembers,
        });

        try {
            await channel.create();
            console.log('Channel created successfully');
        } catch (channelError) {
            console.log('Channel might already exist:', channelError.message);
            // Channel exists, which is fine
        }

        const token = serverClient.createToken(userId);
        
        return { 
            token: token,
            apiKey: apiKey,
            groupName: groupData.name || "BiteMates Chat",
            success: true
        };

    } catch (error) {
        console.error(`Error in getGroupChatToken:`, error);
        if (error instanceof functions.https.HttpsError) {
            throw error; 
        } 
        throw new functions.https.HttpsError("internal", `Chat setup failed: ${error.message}`);
    }
});


// Development-friendly matching function with smaller group sizes
const createGroups = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const currentUserId = context.auth.uid;
    const GROUP_SIZE = 2; // Reduced to 2 for development with 3 users
    const MAX_GROUP_SIZE = 3; // Allow up to 3 users per group

    console.log(`createGroups called by user: ${currentUserId}`);

    // Use transaction to prevent race conditions
    const result = await db.runTransaction(async (transaction) => {
        // Check if current user is still waiting
        const currentUserRef = db.collection('users').doc(currentUserId);
        const currentUserDoc = await transaction.get(currentUserRef);
        
        if (!currentUserDoc.exists) {
            throw new functions.https.HttpsError("not-found", "User not found.");
        }
        
        const userData = currentUserDoc.data();
        if (!userData.isWaitingForGroup || userData.groupAssigned) {
            return { status: 'User is no longer waiting for a group.' };
        }

        // Get all waiting users (including current user)
        const waitingUsersSnapshot = await transaction.get(
            db.collection('users')
                .where('isWaitingForGroup', '==', true)
                .where('groupAssigned', '==', false)
        );

        console.log(`Found ${waitingUsersSnapshot.docs.length} waiting users`);

        if (waitingUsersSnapshot.docs.length < GROUP_SIZE) {
            console.log(`Only ${waitingUsersSnapshot.docs.length} users waiting, need at least ${GROUP_SIZE}`);
            return { status: `Not enough users waiting. Found ${waitingUsersSnapshot.docs.length}, need at least ${GROUP_SIZE}.` };
        }

        const waitingUsers = waitingUsersSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

        // For development: Create a group with all available users (up to MAX_GROUP_SIZE)
        const groupMembers = waitingUsers.slice(0, Math.min(waitingUsers.length, MAX_GROUP_SIZE));
        const memberIds = groupMembers.map(user => user.id);

        console.log(`Creating development group with users: ${memberIds.join(', ')}`);

        const groupRef = db.collection('groups').doc();
        const groupName = `BiteMates Dev Group (${groupMembers.length} members)`;
        
        // Create group document
        transaction.set(groupRef, {
            name: groupName,
            members: memberIds,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            matchingCriteria: 'development',
            groupType: 'dev_test',
        });

        // Update all member users
        for (const member of groupMembers) {
            const userRef = db.collection('users').doc(member.id);
            transaction.update(userRef, { 
                groupId: groupRef.id, 
                isWaitingForGroup: false, 
                groupAssigned: true,
                assignedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        console.log(`Created group ${groupRef.id} with ${memberIds.length} members: ${memberIds.join(', ')}`);

        return { 
            status: 'Success: Development group created!',
            groupId: groupRef.id,
            groupName: groupName,
            memberCount: memberIds.length,
            members: memberIds,
            userAssigned: memberIds.includes(currentUserId)
        };
    });

    console.log(`createGroups result:`, result);
    return result;
});

// Development helper function to reset all users for testing
const resetUsersForTesting = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    console.log(`resetUsersForTesting called by user: ${context.auth.uid}`);

    try {
        const batch = db.batch();

        // Get all users
        const usersSnapshot = await db.collection('users').get();
        console.log(`Found ${usersSnapshot.docs.length} users to reset`);

        // Reset all users to waiting state
        usersSnapshot.docs.forEach(doc => {
            const userRef = db.collection('users').doc(doc.id);
            batch.update(userRef, {
                isWaitingForGroup: true,
                groupAssigned: false,
                groupId: admin.firestore.FieldValue.delete(),
                assignedAt: admin.firestore.FieldValue.delete(),
            });
        });

        // Delete all existing groups
        const groupsSnapshot = await db.collection('groups').get();
        console.log(`Found ${groupsSnapshot.docs.length} groups to delete`);
        
        groupsSnapshot.docs.forEach(doc => {
            batch.delete(doc.ref);
        });

        await batch.commit();

        return { 
            status: 'Success: All users reset for testing',
            usersReset: usersSnapshot.docs.length,
            groupsDeleted: groupsSnapshot.docs.length
        };
    } catch (error) {
        console.error('Error resetting users:', error);
        throw new functions.https.HttpsError("internal", "Failed to reset users for testing.");
    }
});

// Test function to verify Stream Chat credentials
const testStreamChat = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    try {
        const apiKey = process.env.STREAM_API_KEY;
        const apiSecret = process.env.STREAM_API_SECRET;
        
        console.log('Testing Stream Chat credentials...');
        console.log('API Key:', apiKey ? 'Present' : 'Missing');
        console.log('API Secret:', apiSecret ? 'Present (length: ' + apiSecret.length + ')' : 'Missing');
        
        if (!apiKey || !apiSecret) {
            return {
                success: false,
                error: 'Stream Chat credentials missing',
                apiKey: apiKey ? 'present' : 'missing',
                apiSecret: apiSecret ? 'present' : 'missing'
            };
        }

        const serverClient = StreamChat.getInstance(apiKey, apiSecret);
        const testUserId = context.auth.uid;
        
        // Test token creation
        const token = serverClient.createToken(testUserId);
        
        console.log('Token created successfully for user:', testUserId);
        
        return {
            success: true,
            message: 'Stream Chat credentials are working!',
            apiKey: apiKey,
            tokenLength: token.length,
            userId: testUserId
        };

    } catch (error) {
        console.error('Stream Chat test error:', error);
        return {
            success: false,
            error: error.message,
            stack: error.stack
        };
    }
});

module.exports = {
    getStreamToken,
    getGroupChatToken,
    createGroups,
    resetUsersForTesting,
    testStreamChat, // Add the test function
};
