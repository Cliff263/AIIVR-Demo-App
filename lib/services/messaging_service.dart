
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';

class MessagingService extends ChangeNotifier {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _logger = Logger();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
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
    final token = await _messaging.getToken();
    _logger.i('FCM Token: $token');

    // Handle token refresh
    _messaging.onTokenRefresh.listen((token) {
      _logger.i('FCM Token refreshed: $token');
      _saveTokenToDatabase(token);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.i('Got a message whilst in the foreground!');
      _logger.i('Message data: ${message.data}');

      if (message.notification != null) {
        _logger.i(
          'Message also contained a notification: ${message.notification}',
        );
        
        // Show notification using Awesome Notifications
        NotificationService().showNotification(
          title: message.notification?.title ?? 'New Message',
          body: message.notification?.body ?? 'You have a new message',
          payload: message.data.toString(),
        );
      }
    });

    // Handle notification clicks when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.i('Message opened from background: ${message.data}');
      _handleNotificationClick(message.data);
    });
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    if (data.containsKey('chatId')) {
      navigatorKey.currentState?.pushNamed('/chat', arguments: data['chatId']);
    } else if (data.containsKey('messageId')) {
      navigatorKey.currentState?.pushNamed('/message', arguments: data['messageId']);
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    _logger.i('Subscribed to topic: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    _logger.i('Unsubscribed from topic: $topic');
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