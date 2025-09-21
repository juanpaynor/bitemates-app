
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

class ChatScreen extends StatelessWidget {
  final String channelId;

  const ChatScreen({super.key, required this.channelId});

  @override
  Widget build(BuildContext context) {
    return StreamChannel(
      channel: StreamChat.of(context).client.channel('messaging', id: channelId),
      child: Scaffold(
        appBar: const StreamChannelHeader(),
        body: Column(
          children: const <Widget>[
            Expanded(
              child: StreamMessageListView(),
            ),
            StreamMessageInput(),
          ],
        ),
      ),
    );
  }
}
