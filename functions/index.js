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

        // Create/get channel with proper member list
        const currentMembers = groupData.members || [];

        const channel = serverClient.channel("messaging", groupId, {
            name: groupData.name || "BiteMates Chat",
            created_by_id: userId,
            members: currentMembers,
        });

        try {
            // Try to create the channel first
            await channel.create();
            console.log('Channel created successfully');
        } catch (channelError) {
            console.log('Channel might already exist, trying to update members:', channelError.message);
            
            // If channel exists, make sure all current group members are in the channel
            try {
                await channel.addMembers(currentMembers);
                console.log('Updated channel members successfully');
            } catch (addMemberError) {
                console.log('Some members might already be in channel:', addMemberError.message);
                // This is fine, members might already be in the channel
            }
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

        // Enhanced matching with personality compatibility
        const groups = createCompatibleGroups(waitingUsers, GROUP_SIZE, MAX_GROUP_SIZE);
        
        if (groups.length === 0) {
            console.log('No compatible groups could be formed');
            return { status: 'Not enough compatible users to form a group.' };
        }

        const results = [];
        
        // Create all compatible groups in this transaction
        for (let i = 0; i < groups.length; i++) {
            const group = groups[i];
            const memberIds = group.map(user => user.id);
            
            const groupRef = db.collection('groups').doc();
            const groupName = generateFunGroupName(group); // Generate creative name
            
            // Calculate group compatibility score
            const compatibilityScore = calculateGroupCompatibility(group);
            
            // Create group document with enhanced data
            transaction.set(groupRef, {
                name: groupName,
                members: memberIds,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                matchingCriteria: 'personality_based',
                compatibilityScore: compatibilityScore,
                groupType: 'personality_matched',
                personalityMix: getPersonalityMix(group),
            });

            // Update all member users
            for (const member of group) {
                const userRef = db.collection('users').doc(member.id);
                transaction.update(userRef, { 
                    groupId: groupRef.id, 
                    isWaitingForGroup: false, 
                    groupAssigned: true,
                    assignedAt: admin.firestore.FieldValue.serverTimestamp(),
                    compatibilityScore: compatibilityScore,
                });
            }

            console.log(`Created personality-matched group ${groupRef.id} with ${memberIds.length} members: ${memberIds.join(', ')}, compatibility: ${compatibilityScore}`);

            results.push({
                groupId: groupRef.id,
                groupName: groupName,
                memberCount: memberIds.length,
                members: memberIds,
                compatibilityScore: compatibilityScore,
                userAssigned: memberIds.includes(currentUserId)
            });
        }

        const totalUsersGrouped = results.reduce((sum, result) => sum + result.memberCount, 0);
        console.log(`Created ${results.length} personality-matched groups with ${totalUsersGrouped} total users`);

        return { 
            status: `Success: ${results.length} personality-matched group(s) created!`,
            groups: results,
            totalGroups: results.length,
            totalUsersGrouped: totalUsersGrouped,
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

// Enhanced personality-based matching functions
function createCompatibleGroups(users, minSize = 2, maxSize = 3) {
    console.log(`Creating compatible groups from ${users.length} users`);
    
    // Filter users with complete personality data
    const usersWithPersonality = users.filter(user => {
        const hasPersonalityObj = user.personality && typeof user.personality === 'object';
        const hasQuizResult = user.quizResult || (user.personality && user.personality.quiz_result);
        return hasPersonalityObj || hasQuizResult;
    });

    console.log(`Found ${usersWithPersonality.length} users with personality data`);

    if (usersWithPersonality.length < minSize) {
        console.log('Not enough users with personality data for matching');
        // Fallback: create simple groups without personality matching
        return createSimpleGroups(users, minSize, maxSize);
    }

    const groups = [];
    const remainingUsers = [...usersWithPersonality];

    while (remainingUsers.length >= minSize) {
        const currentGroup = [remainingUsers.shift()]; // Start with first user
        
        // Find compatible users for this group
        while (currentGroup.length < maxSize && remainingUsers.length > 0) {
            const bestMatch = findBestMatch(currentGroup, remainingUsers);
            if (bestMatch !== -1) {
                currentGroup.push(remainingUsers.splice(bestMatch, 1)[0]);
            } else {
                break; // No good matches found
            }
        }

        if (currentGroup.length >= minSize) {
            groups.push(currentGroup);
            console.log(`Created group with ${currentGroup.length} members`);
        }
    }

    // If we have leftover users and existing groups, try to add them
    if (remainingUsers.length > 0 && groups.length > 0) {
        for (const user of remainingUsers) {
            // Find group with space and best compatibility
            let bestGroupIndex = -1;
            let bestScore = -1;
            
            for (let i = 0; i < groups.length; i++) {
                if (groups[i].length < maxSize) {
                    const testGroup = [...groups[i], user];
                    const score = calculateGroupCompatibility(testGroup);
                    if (score > bestScore) {
                        bestScore = score;
                        bestGroupIndex = i;
                    }
                }
            }
            
            if (bestGroupIndex !== -1) {
                groups[bestGroupIndex].push(user);
                console.log(`Added leftover user to group ${bestGroupIndex + 1}`);
            }
        }
    }

    console.log(`Created ${groups.length} personality-matched groups`);
    return groups;
}

function createSimpleGroups(users, minSize, maxSize) {
    console.log('Creating simple groups without personality matching');
    const groups = [];
    const remainingUsers = [...users];

    while (remainingUsers.length >= minSize) {
        const groupSize = Math.min(maxSize, remainingUsers.length);
        const group = remainingUsers.splice(0, groupSize);
        groups.push(group);
    }

    return groups;
}

function findBestMatch(currentGroup, candidates) {
    let bestScore = -1;
    let bestIndex = -1;

    for (let i = 0; i < candidates.length; i++) {
        const testGroup = [...currentGroup, candidates[i]];
        const compatibilityScore = calculateGroupCompatibility(testGroup);
        
        if (compatibilityScore > bestScore) {
            bestScore = compatibilityScore;
            bestIndex = i;
        }
    }

    return bestIndex;
}

function calculateGroupCompatibility(group) {
    if (group.length < 2) return 0;
    
    let totalScore = 0;
    let comparisons = 0;

    // Compare each pair of users in the group
    for (let i = 0; i < group.length; i++) {
        for (let j = i + 1; j < group.length; j++) {
            const score = calculateUserCompatibility(group[i], group[j]);
            totalScore += score;
            comparisons++;
        }
    }

    const avgScore = comparisons > 0 ? totalScore / comparisons : 0;
    
    // Bonus for personality diversity (avoid all same types)
    const diversityBonus = calculateDiversityBonus(group);
    
    return Math.round((avgScore + diversityBonus) * 100) / 100;
}

function calculateUserCompatibility(user1, user2) {
    // Get personality data for both users
    const personality1 = getUserPersonalityData(user1);
    const personality2 = getUserPersonalityData(user2);
    
    if (!personality1 || !personality2) {
        return 0.5; // Neutral compatibility if no personality data
    }

    let score = 0;
    let factors = 0;

    // Extraversion compatibility (complementary is good)
    if (personality1.extraversion !== undefined && personality2.extraversion !== undefined) {
        const extroversionDiff = Math.abs(personality1.extraversion - personality2.extraversion);
        // Sweet spot: not too similar, not too different (scale 0-8)
        const extroversionScore = extroversionDiff >= 2 && extroversionDiff <= 5 ? 0.8 : 0.4;
        score += extroversionScore;
        factors++;
    }

    // Openness compatibility (similar is good)
    if (personality1.openness !== undefined && personality2.openness !== undefined) {
        const opennessDiff = Math.abs(personality1.openness - personality2.openness);
        // Similar openness works well (scale 0-4)
        const opennessScore = opennessDiff <= 1 ? 0.9 : (opennessDiff <= 2 ? 0.6 : 0.3);
        score += opennessScore;
        factors++;
    }

    // Chill factor compatibility (mixed is good)
    if (personality1.chill_factor !== undefined && personality2.chill_factor !== undefined) {
        const chillDiff = Math.abs(personality1.chill_factor - personality2.chill_factor);
        // Moderate differences work well (scale 0-5)
        const chillScore = chillDiff >= 1 && chillDiff <= 3 ? 0.7 : 0.4;
        score += chillScore;
        factors++;
    }

    // Interest overlap (some common ground is good)
    if (personality1.interests && personality2.interests && 
        Array.isArray(personality1.interests) && Array.isArray(personality2.interests)) {
        const commonInterests = personality1.interests.filter(interest => 
            personality2.interests.includes(interest)
        );
        const interestScore = commonInterests.length > 0 ? 0.8 : 0.5;
        score += interestScore;
        factors++;
    }

    // Location compatibility (same sector is a plus)
    if (user1.location && user2.location) {
        const locationScore = user1.location === user2.location ? 0.7 : 0.5;
        score += locationScore;
        factors++;
    }

    return factors > 0 ? score / factors : 0.5;
}

function getUserPersonalityData(user) {
    // Try to get detailed personality object first
    if (user.personality && typeof user.personality === 'object') {
        return user.personality;
    }
    
    // Fallback to quizResult string mapping
    const quizResult = user.quizResult || (user.personality && user.personality.quiz_result);
    if (quizResult) {
        // Map simple quiz results to estimated personality values
        switch (quizResult) {
            case 'social':
                return { extraversion: 6, openness: 2, chill_factor: 2, interests: ['social'] };
            case 'explorer':
                return { extraversion: 4, openness: 4, chill_factor: 1, interests: ['adventure'] };
            case 'chill':
                return { extraversion: 2, openness: 2, chill_factor: 4, interests: ['relaxing'] };
            case 'balanced':
                return { extraversion: 3, openness: 2, chill_factor: 3, interests: ['varied'] };
            default:
                return null;
        }
    }
    
    return null;
}

function calculateDiversityBonus(group) {
    const quizResults = group.map(user => 
        user.quizResult || 
        (user.personality && user.personality.quiz_result) || 
        'unknown'
    );
    
    const uniqueTypes = new Set(quizResults);
    
    // Bonus for having 2-3 different personality types in group
    if (uniqueTypes.size >= 2 && uniqueTypes.size <= 3) {
        return 0.2;
    }
    
    return 0;
}

function getPersonalityMix(group) {
    const quizResults = group.map(user => 
        user.quizResult || 
        (user.personality && user.personality.quiz_result) || 
        'unknown'
    );
    
    const counts = {};
    quizResults.forEach(result => {
        counts[result] = (counts[result] || 0) + 1;
    });
    
    return counts;
}

// Fun group name generator
function generateFunGroupName(group) {
    const adjectives = [
        'Hungry', 'Spicy', 'Sweet', 'Crispy', 'Juicy', 'Fresh', 'Tasty', 'Zesty',
        'Saucy', 'Cheesy', 'Smoky', 'Savory', 'Delicious', 'Crunchy', 'Tender',
        'Flavorful', 'Steamy', 'Golden', 'Creamy', 'Tangy', 'Bold', 'Rich'
    ];
    
    const foodNouns = [
        'Foodies', 'Munchers', 'Biters', 'Chefs', 'Cooks', 'Tasters', 'Gourmets',
        'Snackers', 'Eaters', 'Feeders', 'Devourers', 'Slurpers', 'Nibblers',
        'Chompers', 'Diners', 'Feast Squad', 'Bite Club', 'Food Gang', 'Flavor Crew',
        'Nom Squad', 'Yum Team', 'Spoon Squad', 'Fork Force', 'Plate Pack'
    ];
    
    const themes = [
        'Kitchen', 'Bistro', 'Cafe', 'Diner', 'Grill', 'Table', 'Pantry',
        'Recipe', 'Buffet', 'Menu', 'Dish', 'Meal', 'Brunch', 'Dinner'
    ];
    
    // Get personality mix for themed names
    const personalityMix = getPersonalityMix(group);
    const dominantPersonality = Object.keys(personalityMix).reduce((a, b) => 
        personalityMix[a] > personalityMix[b] ? a : b
    );
    
    // Personality-based name variations
    let nameStyle = Math.random();
    let groupName;
    
    if (nameStyle < 0.3) {
        // Style 1: "The [Adjective] [Food Noun]"
        const adj = adjectives[Math.floor(Math.random() * adjectives.length)];
        const noun = foodNouns[Math.floor(Math.random() * foodNouns.length)];
        groupName = `The ${adj} ${noun}`;
    } else if (nameStyle < 0.6) {
        // Style 2: "[Theme] [Number/Letter]" 
        const theme = themes[Math.floor(Math.random() * themes.length)];
        const suffix = Math.random() < 0.5 ? 
            (Math.floor(Math.random() * 99) + 1).toString() :
            String.fromCharCode(65 + Math.floor(Math.random() * 26)); // A-Z
        groupName = `${theme} ${suffix}`;
    } else {
        // Style 3: Personality-themed names
        switch (dominantPersonality) {
            case 'social':
                groupName = `The Social ${foodNouns[Math.floor(Math.random() * foodNouns.length)]}`;
                break;
            case 'explorer':
                groupName = `Adventure ${themes[Math.floor(Math.random() * themes.length)]}`;
                break;
            case 'chill':
                groupName = `Chill ${adjectives[Math.floor(Math.random() * adjectives.length)]} Crew`;
                break;
            case 'balanced':
                groupName = `Balanced ${themes[Math.floor(Math.random() * themes.length)]}`;
                break;
            default:
                groupName = `The ${adjectives[Math.floor(Math.random() * adjectives.length)]} ${foodNouns[Math.floor(Math.random() * foodNouns.length)]}`;
        }
    }
    
    // Add emoji for fun
    const emojis = ['🍕', '🍔', '🌮', '🍜', '🍱', '🥘', '🍝', '🥗', '🍲', '🥙', '🌯', '🫔'];
    const emoji = emojis[Math.floor(Math.random() * emojis.length)];
    
    return `${groupName} ${emoji}`;
}

// Function to manage Stream Chat channel membership
const updateChannelMembership = functions.runWith({ secrets: ["STREAM_API_KEY", "STREAM_API_SECRET"] }).https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const { groupId, action, userId } = data; // action: 'add' or 'remove'
    
    if (!groupId || !action) {
        throw new functions.https.HttpsError("invalid-argument", "Missing required parameters: groupId, action");
    }

    try {
        const apiKey = process.env.STREAM_API_KEY;
        const apiSecret = process.env.STREAM_API_SECRET;
        
        if (!apiKey || !apiSecret) {
            throw new functions.https.HttpsError("internal", "Stream Chat not configured");
        }

        const serverClient = StreamChat.getInstance(apiKey, apiSecret);
        const channel = serverClient.channel("messaging", groupId);

        const targetUserId = userId || context.auth.uid;

        if (action === 'add') {
            // Get user data for proper Stream Chat user setup
            const userDoc = await db.collection("users").doc(targetUserId).get();
            const userData = userDoc.data() || {};
            const userNickname = userData.nickname || userData.email || `User_${targetUserId.substring(0, 8)}`;

            // Ensure user exists in Stream Chat
            await serverClient.upsertUser({
                id: targetUserId,
                name: userNickname,
                image: userData.photoUrl || undefined,
            });

            // Add user to channel
            await channel.addMembers([targetUserId]);
            console.log(`Added user ${targetUserId} to channel ${groupId}`);
            
        } else if (action === 'remove') {
            // Remove user from channel
            await channel.removeMembers([targetUserId]);
            console.log(`Removed user ${targetUserId} from channel ${groupId}`);
        }

        return { success: true, action, userId: targetUserId, groupId };

    } catch (error) {
        console.error(`Error updating channel membership:`, error);
        throw new functions.https.HttpsError("internal", `Failed to ${action} user: ${error.message}`);
    }
});

module.exports = {
    getStreamToken,
    getGroupChatToken,
    createGroups,
    resetUsersForTesting,
    testStreamChat, // Add the test function
    updateChannelMembership,
};
