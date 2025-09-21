import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:stream_chat_flutter/stream_chat_flutter.dart' as stream;

class ChatService {
  final stream.StreamChatClient client;

  ChatService(this.client);

  Future<void> connectUser(auth.User firebaseUser, String nickname, String photoUrl) async {
    try {
      // Call the Cloud Function to get a token for the user.
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('stream-getStreamUserToken');
      final response = await callable.call();
      final token = response.data['token'];

      if (token == null) {
        throw Exception('Stream token was null.');
      }

      // Connect the user to Stream using the fetched token.
      await client.connectUser(
        stream.User(
          id: firebaseUser.uid,
          extraData: {
            'name': nickname, // Use 'name' for the user's display name
            'image': photoUrl,
          },
        ),
        token,
      );
    } on FirebaseFunctionsException catch (e) {
      print("FirebaseFunctionsException when connecting user to Stream: ${e.code} - ${e.message}");
      // Optionally, re-throw or handle the error in the UI
      throw e;
    } catch (e) {
      print("An unexpected error occurred when connecting user to Stream: $e");
      throw e;
    }
  }

  Future<void> disconnectUser() async {
    try {
      await client.disconnectUser();
    } catch (e) {
      print("Error disconnecting user from Stream: $e");
      // It's often safe to ignore this error, but we log it for debugging.
    }
  }
}
