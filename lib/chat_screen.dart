import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:go_router/go_router.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;
  const ChatScreen({super.key, required this.groupId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  StreamChatClient? _client;
  Channel? _channel;
  late final Future<void> _connectFuture;
  List<Map<String, dynamic>> _groupMembers = [];
  String _groupName = "BiteMates Chat";
  bool _isEditingGroupName = false;
  final TextEditingController _groupNameController = TextEditingController();
  bool _showEmojiPicker = false;
  final StreamMessageInputController _messageController = StreamMessageInputController();
  final TextEditingController _textController = TextEditingController();
  
  // New state for dinner planning
  String _userChoice = ''; // 'skip' or 'stay'
  Map<String, String> _memberChoices = {}; // memberId -> choice
  int _stayCount = 0;
  bool _isDinnerPlanningExpanded = true; // Controls the drawer-like behavior

  @override
  void initState() {
    super.initState();
    // Initialize client without API key - will get it from backend
    _connectFuture = _initializeChat();
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    try {
      final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('No current user found');
        return;
      }

      final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();
      final groupData = groupDoc.data();
      
      if (!groupDoc.exists || groupData == null) {
        debugPrint('Group not found: ${widget.groupId}');
        _showNotMemberDialog('Group not found', 'This group no longer exists.');
        return;
      }

      final memberIds = List<String>.from(groupData['members'] ?? []);
      
      // Check if current user is a member
      if (!memberIds.contains(currentUser.uid)) {
        debugPrint('User ${currentUser.uid} is not a member of group ${widget.groupId}');
        _showNotMemberDialog('Not a Member', 'You are no longer a member of this group.');
        return;
      }

      if (mounted) {
        setState(() {
          _groupName = groupData['name'] ?? 'BiteMates Chat';
          _groupNameController.text = _groupName;
        });
      }

      final members = <Map<String, dynamic>>[];
      for (String memberId in memberIds) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(memberId).get();
        final userData = userDoc.data();
        if (userData != null) {
          members.add({
            'id': memberId,
            'nickname': userData['nickname'] ?? 'Unknown',
            'profile_picture_url': userData['profile_picture_url'],
            'personality': userData['personality'],
          });
        }
      }

      if (mounted) {
        setState(() {
          _groupMembers = members;
        });
      }

      // Load existing dinner choices
      await _loadExistingDinnerChoices();
    } catch (e) {
      debugPrint('Error loading group data: $e');
      _showNotMemberDialog('Error', 'Unable to load group data. Please try again.');
    }
  }

  Future<void> _loadExistingDinnerChoices() async {
    try {
      final choicesSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('dinner_choices')
          .get();

      final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
      final choices = <String, String>{};
      
      for (var doc in choicesSnapshot.docs) {
        final data = doc.data();
        choices[doc.id] = data['choice'] ?? '';
        
        // Set current user's choice if found
        if (currentUser != null && doc.id == currentUser.uid) {
          _userChoice = data['choice'] ?? '';
        }
      }

      if (mounted) {
        setState(() {
          _memberChoices = choices;
          _updateStayCount();
        });
      }
    } catch (e) {
      debugPrint('Error loading dinner choices: $e');
    }
  }

  Future<void> _initializeChat() async {
    try {
      final firebaseUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw Exception('User is not authenticated with Firebase.');
      }
      final userId = firebaseUser.uid;

      debugPrint('🔵 Starting chat initialization for user: $userId, group: ${widget.groupId}');

      // Get Stream Chat token and API key from backend
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getGroupChatToken');
      
      debugPrint('🔵 Calling getGroupChatToken function...');
      
      final results = await callable.call(<String, dynamic>{
        'groupId': widget.groupId,
      });
      
      debugPrint('🟢 Function call successful: ${results.data}');
      
      final token = results.data['token'];
      final apiKey = results.data['apiKey'];
      
      if (token == null || apiKey == null) {
        throw Exception('Failed to get Stream Chat credentials from backend.');
      }

      debugPrint('🔵 Got credentials - API Key: $apiKey, Token length: ${token.length}');

      // Initialize client with API key from backend and proper configuration
      _client = StreamChatClient(
        apiKey,
        logLevel: Level.WARNING, // Reduce logging to only warnings and errors
      );

      debugPrint('🔵 Connecting user to Stream Chat...');

      // Create user object with more details
      final user = User(
        id: userId,
        name: firebaseUser.displayName ?? firebaseUser.email ?? 'User',
        image: firebaseUser.photoURL,
      );

      // Connect with retry logic
      await _connectWithRetry(user, token);
      debugPrint('🟢 User connected successfully');

      // Initialize channel with proper error handling
      _channel = _client!.channel(
        'messaging', 
        id: widget.groupId,
        extraData: {
          'name': 'BiteMates Chat',
          'image': 'https://bit.ly/2TIt8NR',
        },
      );

      debugPrint('🔵 Watching channel...');
      await _channel!.watch();
      debugPrint('🟢 Channel watch successful');

    } catch (e, st) {
      debugPrint('🔴 Error connecting user to group chat: $e');
      debugPrint('🔴 Stack trace: $st');
      rethrow;
    }
  }

  Future<void> _connectWithRetry(User user, String token) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        await _client!.connectUser(user, token);
        return; // Success
      } catch (e) {
        retryCount++;
        debugPrint('🔄 Connection attempt $retryCount failed: $e');
        
        if (retryCount >= maxRetries) {
          throw Exception('Failed to connect after $maxRetries attempts: $e');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }
  }
  
  Future<void> _updateGroupName(String newName) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({'name': newName});
      
      // Also update the Stream Chat channel
      if (_channel != null) {
        await _channel!.updatePartial(set: {'name': newName});
      }
      
      setState(() {
        _groupName = newName;
        _isEditingGroupName = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name updated!')),
      );
    } catch (e) {
      debugPrint('Error updating group name: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update group name')),
      );
    }
  }

  void _showMembersBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Group Members',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._groupMembers.map((member) => ListTile(
              leading: CircleAvatar(
                backgroundImage: member['profile_picture_url'] != null
                    ? NetworkImage(member['profile_picture_url'])
                    : null,
                backgroundColor: const Color(0xFFFF6B35),
                child: member['profile_picture_url'] == null
                    ? Text(
                        member['nickname'][0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      )
                    : null,
              ),
              title: Text(member['nickname']),
              subtitle: member['personality'] != null 
                  ? Text(_getPersonalityString(member['personality']))
                  : const Text('No personality data'),
            )).toList(),
          ],
        ),
      ),
    );
  }

  String _getPersonalityString(Map<String, dynamic> personality) {
    if (personality['quiz_result'] != null) {
      return '${personality['quiz_result']} personality';
    }
    return 'Mixed personality';
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
    
    // Hide keyboard when showing emoji picker
    if (_showEmojiPicker) {
      FocusScope.of(context).unfocus();
    }
  }

  void _onEmojiSelected(Emoji emoji) {
    final currentText = _textController.text;
    final selection = _textController.selection;
    
    final newText = currentText.replaceRange(
      selection.start,
      selection.end,
      emoji.emoji,
    );
    
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.emoji.length,
      ),
    );
    
    // Keep focus on text field
    _textController.selection = TextSelection.collapsed(
      offset: selection.start + emoji.emoji.length,
    );
  }


  @override
  void dispose() {
    // Properly cleanup Stream Chat connections
    _cleanupConnections();
    _groupNameController.dispose();
    _textController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _cleanupConnections() {
    try {
      _channel?.stopWatching();
      _client?.disconnectUser();
    } catch (e) {
      debugPrint('Error during Stream Chat cleanup: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Back to white background
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            context.pop();
          },
        ),
        title: _isEditingGroupName
            ? TextField(
                controller: _groupNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter group name',
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _updateGroupName(value.trim());
                  } else {
                    setState(() {
                      _isEditingGroupName = false;
                    });
                  }
                },
                autofocus: true,
              )
            : GestureDetector(
                onTap: () {
                  setState(() {
                    _isEditingGroupName = true;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _groupName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 16, color: Colors.white70),
                  ],
                ),
              ),
        backgroundColor: const Color(0xFFFF6B35), // Back to original orange
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.group, color: Colors.white),
            onPressed: _showMembersBottomSheet,
            tooltip: 'View Members',
          ),
        ],
      ),
      body: FutureBuilder(
        future: _connectFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading group...',
                    style: TextStyle(color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Checking your membership and setting up chat',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Chat Connection Error',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Unable to connect to the chat.\n\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            // Retry connection
                            setState(() {
                              _connectFuture = _initializeChat();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                          ),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            // Try to go back gracefully, fall back to home if needed
                            try {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/home');
                              }
                            } catch (e) {
                              // Fallback - force navigation to home
                              context.go('/home');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                          ),
                          child: const Text('Go Back', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          // Successfully connected - show chat
          return StreamChat(
            client: _client!,
            child: StreamChannel(
              channel: _channel!,
              child: Column(
                children: [
                  // Skip/Stay buttons section - always visible
                  _buildSkipStaySection(),
                  
                  // Chat messages with original theme
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      child: const StreamMessageListView(),
                    ),
                  ),
                  // Custom message input section with original theme
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Message input with original styling
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              // GIF button
                              IconButton(
                                icon: Icon(
                                  Icons.gif,
                                  color: const Color(0xFFFF6B35),
                                  size: 28,
                                ),
                                onPressed: () => _showGifShortcuts(),
                                tooltip: 'Send GIF',
                              ),
                              // Emoji button
                              IconButton(
                                icon: Icon(
                                  _showEmojiPicker 
                                      ? Icons.keyboard 
                                      : Icons.emoji_emotions_outlined,
                                  color: const Color(0xFFFF6B35),
                                  size: 28,
                                ),
                                onPressed: _toggleEmojiPicker,
                                tooltip: _showEmojiPicker ? 'Hide emoji picker' : 'Show emoji picker',
                              ),
                              // Expanded text input
                              Expanded(
                                child: Container(
                                  constraints: const BoxConstraints(maxHeight: 120),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: TextField(
                                    controller: _textController,
                                    style: const TextStyle(color: Colors.black87),
                                    decoration: const InputDecoration(
                                      hintText: 'Type a message...',
                                      hintStyle: TextStyle(color: Colors.grey),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                    ),
                                    maxLines: null,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (value) => _sendMessage(),
                                  ),
                                ),
                              ),
                              // Send button
                              IconButton(
                                icon: const Icon(
                                  Icons.send,
                                  color: Color(0xFFFF6B35),
                                  size: 28,
                                ),
                                onPressed: _sendMessage,
                                tooltip: 'Send message',
                              ),
                            ],
                          ),
                        ),
                        
                        // Quick emoji bar (when emoji picker is not showing) - Original theme
                        if (!_showEmojiPicker)
                          Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                const Text('Quick: ', 
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: Colors.grey,
                                  ),
                                ),
                                ...[
                                  '😂', '❤️', '👍', '😍', '😋', '🔥', '👏', '😊'
                                ].map((emoji) => GestureDetector(
                                  onTap: () => _sendQuickEmoji(emoji),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.transparent,
                                    ),
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ),
                                )).toList(),
                              ],
                            ),
                          ),
                        // Emoji picker with original theme
                        if (_showEmojiPicker)
                          Container(
                            height: 250,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: EmojiPicker(
                              onEmojiSelected: (category, emoji) {
                                _onEmojiSelected(emoji);
                              },
                              config: Config(
                                height: 256,
                                checkPlatformCompatibility: true,
                                emojiViewConfig: EmojiViewConfig(
                                  columns: 7,
                                  emojiSizeMax: 32,
                                  verticalSpacing: 0,
                                  horizontalSpacing: 0,
                                  gridPadding: EdgeInsets.zero,
                                  backgroundColor: Colors.white,
                                ),
                                skinToneConfig: const SkinToneConfig(),
                                categoryViewConfig: const CategoryViewConfig(),
                                bottomActionBarConfig: const BottomActionBarConfig(),
                                searchViewConfig: const SearchViewConfig(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isNotEmpty && _channel != null) {
      try {
        await _channel!.sendMessage(Message(text: text));
        _textController.clear();
        // Hide emoji picker after sending
        if (_showEmojiPicker) {
          setState(() {
            _showEmojiPicker = false;
          });
        }
      } catch (e) {
        debugPrint('Error sending message: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send message. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Widget _buildSkipStaySection() {
    // Show minimized version if collapsed
    if (!_isDinnerPlanningExpanded) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF6B35).withOpacity(0.1),
              const Color(0xFFFF6B35).withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFFFF6B35).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.restaurant,
              color: const Color(0xFFFF6B35),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Group Dinner Planning',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2B2B2B),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _isDinnerPlanningExpanded = true;
                });
              },
              icon: Icon(
                Icons.expand_more,
                color: const Color(0xFFFF6B35),
                size: 24,
              ),
              tooltip: 'Show dinner planning',
            ),
          ],
        ),
      );
    }

    // Show full version if expanded
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withOpacity(0.1),
            const Color(0xFFFF6B35).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFFF6B35).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant,
                color: const Color(0xFFFF6B35),
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Group Dinner Planning',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2B2B2B),
                  ),
                ),
              ),
              // Collapse/Expand button
              IconButton(
                icon: Icon(
                  Icons.expand_less,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isDinnerPlanningExpanded = false;
                  });
                },
                tooltip: 'Minimize dinner planning',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Ready to meet up for dinner? Choose your preference:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // Skip/Stay buttons
          Row(
            children: [
              Expanded(
                child: _buildChoiceButton(
                  choice: 'skip',
                  label: 'Skip This Time',
                  icon: Icons.not_interested,
                  color: Colors.grey.shade600,
                  isSelected: _userChoice == 'skip',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildChoiceButton(
                  choice: 'stay',
                  label: 'Let\'s Meet Up!',
                  icon: Icons.restaurant_menu,
                  color: const Color(0xFFFF6B35),
                  isSelected: _userChoice == 'stay',
                ),
              ),
            ],
          ),
          
          // Show member choices
          if (_memberChoices.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildMemberChoicesDisplay(),
          ],
          
          // Show dinner planning if enough people stay
          if (_stayCount >= 2 && _userChoice == 'stay') ...[
            const SizedBox(height: 16),
            _buildDinnerPlanningSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildChoiceButton({
    required String choice,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => _makeChoice(choice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: color,
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberChoicesDisplay() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group Responses:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: const Color(0xFF2B2B2B),
            ),
          ),
          const SizedBox(height: 8),
          ..._groupMembers.map((member) {
            final choice = _memberChoices[member['id']] ?? 'waiting';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: member['profile_picture_url'] != null
                        ? NetworkImage(member['profile_picture_url'])
                        : null,
                    backgroundColor: const Color(0xFFFF6B35),
                    child: member['profile_picture_url'] == null
                        ? Text(
                            member['nickname'][0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    member['nickname'],
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const Spacer(),
                  _buildChoiceIndicator(choice),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
          Text(
            '$_stayCount member(s) want to meet up',
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFFFF6B35),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceIndicator(String choice) {
    switch (choice) {
      case 'stay':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restaurant_menu, size: 12, color: const Color(0xFFFF6B35)),
              const SizedBox(width: 2),
              Text(
                'Stay',
                style: TextStyle(
                  fontSize: 10,
                  color: const Color(0xFFFF6B35),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      case 'skip':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.not_interested, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 2),
              Text(
                'Skip',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Deciding...',
            style: TextStyle(
              fontSize: 10,
              color: Colors.orange.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
    }
  }

  Widget _buildDinnerPlanningSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B35).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF6B35).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_available,
                color: const Color(0xFFFF6B35),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Great! Let\'s Plan Your Dinner',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2B2B2B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _showDinnerPlanningModal(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            icon: const Icon(Icons.restaurant),
            label: const Text(
              'Choose Date & Restaurant',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _makeChoice(String choice) async {
    final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _userChoice = choice;
      _memberChoices[currentUser.uid] = choice;
      _updateStayCount();
    });

    // Save choice to Firestore
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('dinner_choices')
          .doc(currentUser.uid)
          .set({
        'choice': choice,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': currentUser.uid,
      });

      // Send a notification message to the chat
      if (_channel != null) {
        try {
          final nickname = _groupMembers
              .firstWhere((m) => m['id'] == currentUser.uid, 
                  orElse: () => {'nickname': 'Someone'})['nickname'];
          
          final message = choice == 'stay' 
              ? '🤖 $nickname wants to meet up for dinner! 🍽️'
              : '🤖 $nickname will skip this dinner 😔';
              
          await _channel!.sendMessage(Message(
            text: message,
          ));
        } catch (e) {
          debugPrint('Error sending notification message: $e');
          // Don't show error to user since the choice was saved successfully
        }
      }

      // If user chose skip, remove them from the group and navigate to matching
      if (choice == 'skip') {
        await _removeUserFromGroup(currentUser.uid);
        _showSkipDialog();
      }
    } catch (e) {
      debugPrint('Error saving dinner choice: $e');
    }
  }

  Future<void> _removeUserFromGroup(String userId) async {
    try {
      // Remove user from group members
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'members': FieldValue.arrayRemove([userId]),
      });

      // Remove user from Stream Chat channel
      final functions = FirebaseFunctions.instance;
      final updateChannelCallable = functions.httpsCallable('updateChannelMembership');
      
      await updateChannelCallable.call(<String, dynamic>{
        'groupId': widget.groupId,
        'action': 'remove',
        'userId': userId,
      });

      // Remove user's dinner choice
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('dinner_choices')
          .doc(userId)
          .delete();

      debugPrint('User removed from group successfully');
    } catch (e) {
      debugPrint('Error removing user from group: $e');
    }
  }

  void _showSkipDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.search,
              color: const Color(0xFFFF6B35),
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text('Find New Group'),
          ],
        ),
        content: const Text(
          'You\'ve left this dinner group. Would you like to search for a new group of BiteMates?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              context.pop(); // Go back to previous screen
            },
            child: const Text(
              'Go Back',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              context.go('/matching');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
            ),
            child: const Text('Find New Group'),
          ),
        ],
      ),
    );
  }

  void _updateStayCount() {
    _stayCount = _memberChoices.values.where((choice) => choice == 'stay').length;
  }

  void _showDinnerPlanningModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => _buildDinnerPlanningContent(scrollController),
      ),
    );
  }

  Widget _buildDinnerPlanningContent(ScrollController scrollController) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Text(
            'Plan Your Group Dinner',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2B2B2B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a date and time that works for everyone',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateSelection(),
                  const SizedBox(height: 24),
                  _buildTimeSlotSelection(),
                  const SizedBox(height: 24),
                  _buildRestaurantSelection(),
                  const SizedBox(height: 32),
                  _buildConfirmButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelection() {
    final today = DateTime.now();
    final dates = List.generate(7, (index) => today.add(Duration(days: index + 1)));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Date',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2B2B2B),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
              
              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () {
                    // Handle date selection
                  },
                  child: Container(
                    width: 80,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isWeekend 
                            ? const Color(0xFFFF6B35) 
                            : Colors.grey.shade300,
                        width: isWeekend ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _getDayName(date.weekday),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isWeekend 
                                ? const Color(0xFFFF6B35) 
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isWeekend 
                                ? const Color(0xFFFF6B35) 
                                : const Color(0xFF2B2B2B),
                          ),
                        ),
                        Text(
                          _getMonthName(date.month),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotSelection() {
    final timeSlots = [
      '11:30 AM - 1:00 PM',
      '12:30 PM - 2:00 PM', 
      '1:00 PM - 2:30 PM',
      '6:00 PM - 7:30 PM',
      '7:00 PM - 8:30 PM',
      '8:00 PM - 9:30 PM',
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Time Slot',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2B2B2B),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: timeSlots.map((timeSlot) {
            final isLunch = timeSlot.contains('AM') || timeSlot.startsWith('1');
            return InkWell(
              onTap: () {
                // Handle time slot selection
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLunch ? Icons.wb_sunny : Icons.nightlight_round,
                      size: 16,
                      color: isLunch 
                          ? Colors.orange 
                          : const Color(0xFF2B2B2B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeSlot,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF2B2B2B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRestaurantSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Restaurant Suggestions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2B2B2B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Based on your group\'s location sector',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFF6B35).withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.restaurant,
                size: 48,
                color: const Color(0xFFFF6B35),
              ),
              const SizedBox(height: 12),
              Text(
                'Restaurant recommendations will be available soon!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2B2B2B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We\'ll suggest restaurants based on your group\'s preferred location sector.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pop();
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dinner planning feature coming soon! 🍽️'),
              backgroundColor: Color(0xFFFF6B35),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Confirm Dinner Plans',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  void _sendQuickEmoji(String emoji) async {
    if (_channel != null) {
      try {
        await _channel!.sendMessage(Message(text: emoji));
      } catch (e) {
        debugPrint('Error sending quick emoji: $e');
      }
    }
  }

  void _showGifShortcuts() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Quick GIF Reactions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildGifButton('👏', 'Clapping'),
                _buildGifButton('😂', 'Laughing'),
                _buildGifButton('😍', 'Love it'),
                _buildGifButton('🤔', 'Thinking'),
                _buildGifButton('👍', 'Thumbs up'),
                _buildGifButton('🎉', 'Celebration'),
                _buildGifButton('😋', 'Yummy'),
                _buildGifButton('🔥', 'Fire'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGifButton(String emoji, String label) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        if (_channel != null) {
          await _channel!.sendMessage(
            Message(text: '$emoji $label GIF'),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B35).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showNotMemberDialog(String title, String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B2B2B),
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Color(0xFF2B2B2B)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                context.go('/home'); // Go to home
              },
              child: const Text(
                'Go to Home',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                context.go('/matching'); // Go to find new group
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
              ),
              child: const Text('Find New Group'),
            ),
          ],
        );
      },
    );
  }
}
