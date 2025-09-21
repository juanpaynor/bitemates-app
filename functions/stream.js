const functions = require("firebase-functions");
const { StreamChat } = require("stream-chat");

// It's crucial to secure your Stream credentials. We will set these as environment variables
// using the Firebase CLI, so they are not hardcoded in your source code.
const streamApiKey = functions.config().stream.api_key;
const streamApiSecret = functions.config().stream.secret;

// Initialize the Stream Chat server-side client
// The client will not initialize if the keys are missing.
let serverClient;
if (streamApiKey && streamApiSecret) {
    serverClient = StreamChat.getInstance(streamApiKey, streamApiSecret);
} else {
    console.error("Stream API key and/or secret not set. Functions requiring Stream will not work.");
}

/**
 * Creates a Stream user token for the currently authenticated Firebase user.
 * This is a callable function, which is more secure because it automatically
 * handles user authentication.
 */
exports.getStreamUserToken = functions.https.onCall(async (data, context) => {
  // Ensure the function is called by an authenticated user.
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  const userId = context.auth.uid;

  if (!serverClient) {
      console.error("Stream server client is not initialized. Check your environment configuration.");
      throw new functions.https.HttpsError('internal', 'Stream client configuration error.');
  }
  
  try {
    // Create a token for the user. This token is a short-lived credential
    // that the client-side will use to connect to Stream.
    const token = serverClient.createToken(userId);
    console.log(`Successfully created Stream token for user: ${userId}`);
    return { token: token };
  } catch (error) {
    console.error(`Error creating Stream token for user ${userId}:`, error);
    throw new functions.https.HttpsError(
      'internal',
      'An unexpected error occurred while creating the user token.'
    );
  }
});

/**
 * Creates a Stream chat channel for a new group.
 * This is an internal helper function, not exposed as an HTTP endpoint.
 */
exports.createStreamChannel = async (groupId, groupName, userIds) => {
    if (!serverClient) {
        console.error("Stream server client is not initialized. Cannot create channel.");
        return;
    }

    try {
        const channel = serverClient.channel('messaging', groupId, {
            name: groupName,
            created_by_id: userIds[0], // Assign one user as the creator
            members: userIds,
        });
        await channel.create();
        console.log(`Successfully created Stream channel: ${groupName} with ID: ${groupId}`);
    } catch (error) {
        console.error(`Error creating Stream channel for group ${groupId}:`, error);
        // We don't re-throw the error here to avoid failing the entire group creation process
        // if the Stream channel creation fails. Logging is sufficient.
    }
};
