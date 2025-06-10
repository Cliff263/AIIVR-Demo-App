import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

class ChatService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // ignore: prefer_final_fields
  List<types.Message> _messages = [];
  final bool _isLoading = false;

  List<types.Message> get messages => _messages;
  bool get isLoading => _isLoading;

  // Create a new chat room
  Future<String> createChatRoom(List<String> participantIds) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final chatId = DateTime.now().millisecondsSinceEpoch.toString();
    final participants = {
      for (var id in participantIds) id: true
    };

    await _firestore.collection('chats').doc(chatId).set({
      'participants': participants,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'lastMessageTime': null,
    });

    return chatId;
  }

  // Send a message
  Future<void> sendMessage(String chatId, String text) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final message = types.TextMessage(
      author: types.User(id: user.uid),
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
    );

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(message.id)
        .set(message.toJson());

    // Update last message in chat room
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    _messages.add(message);
    notifyListeners();
  }

  // Get messages for a chat room
  Stream<List<types.Message>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => types.TextMessage.fromJson(doc.data()))
          .toList();
    });
  }

  // Get user's chat rooms
  Stream<List<Map<String, dynamic>>> getUserChats() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    return _firestore
        .collection('chats')
        .where('participants.${user.uid}', isEqualTo: true)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'lastMessage': data['lastMessage'],
          'lastMessageTime': data['lastMessageTime'],
          'participants': data['participants'],
        };
      }).toList();
    });
  }

  // Get chat participants
  Future<List<String>> getChatParticipants(String chatId) async {
    final doc = await _firestore.collection('chats').doc(chatId).get();
    if (!doc.exists) throw Exception('Chat not found');

    final participants = doc.data()?['participants'] as Map<String, dynamic>;
    return participants.keys.toList();
  }

  // Mark message as read
  Future<void> markMessageAsRead(String chatId, String messageId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'readBy.${user.uid}': true,
    });
  }
} 