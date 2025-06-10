import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

class MessagingService extends ChangeNotifier {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _logger = Logger();
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    // Request permission for notifications
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    String? token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToDatabase(token);
    }

    // Listen to token refresh
    _messaging.onTokenRefresh.listen(_saveTokenToDatabase);

    // Handle incoming messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
  }

  Future<void> _saveTokenToDatabase(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  Future<void> sendMessage({
    required String receiverId,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) return;

      // Get receiver's FCM tokens
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      final List<dynamic> tokens = receiverDoc.data()?['fcmTokens'] ?? [];

      // Create message document
      final messageDoc = await _firestore.collection('messages').add({
        'senderId': user.uid,
        'receiverId': receiverId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'data': data,
        'status': 'sent',
      });

      // Send FCM notification
      for (String token in tokens) {
        await _firestore.collection('fcm_messages').add({
          'token': token,
          'data': {
            'messageId': messageDoc.id,
            'senderId': user.uid,
            'message': message,
            ...?data,
          },
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // Update message status
      await messageDoc.update({'status': 'delivered'});
    } catch (e) {
      // Log error
      await _firestore.collection('message_errors').add({
        'error': e.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': _auth.currentUser?.uid,
        'receiverId': receiverId,
        'message': message,
      });
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _logger.i('Got a message whilst in the foreground!');
    _logger.d('Message data: ${message.data}');

    if (message.notification != null) {
      _logger.d('Message also contained a notification: ${message.notification}');
    }
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    _logger.i('Handling a background message: ${message.messageId}');
  }

  Stream<QuerySnapshot> getMessageHistory() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('messages')
        .where('receiverId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }
} 