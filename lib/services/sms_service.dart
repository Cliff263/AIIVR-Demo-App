import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SMSService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final bool _isLoading = false;
  final _logger = Logger('SMSService');
  
  // Twilio API Configuration
  static String get _twilioAccountSid => dotenv.env['TWILIO_ACCOUNT_SID'] ?? '';
  static String get _twilioAuthToken => dotenv.env['TWILIO_AUTH_TOKEN'] ?? '';
  static String get _twilioPhoneNumber => dotenv.env['TWILIO_PHONE_NUMBER'] ?? '';
  static String get _twilioApiUrl => 'https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid/Messages.json';

  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    // No initialization needed for Twilio
  }

  Future<void> sendMessage(String phoneNumber, String message) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Create message document in Firestore
      final messageRef = _firestore.collection('messages').doc();
      await messageRef.set({
        'userId': userId,
        'phoneNumber': phoneNumber,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sending',
      });

      // Send SMS via Twilio
      final response = await http.post(
        Uri.parse(_twilioApiUrl),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_twilioAccountSid:$_twilioAuthToken'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'To': phoneNumber,
          'From': _twilioPhoneNumber,
          'Body': message,
        },
      );

      if (response.statusCode == 201) {
        // Message sent successfully
        await messageRef.update({
          'status': 'delivered',
          'twilioSid': jsonDecode(response.body)['sid'],
        });
      } else {
        // Message failed to send
        await messageRef.update({
          'status': 'failed',
          'error': 'Failed to send SMS: ${response.body}',
        });
        throw Exception('Failed to send SMS: ${response.body}');
      }
    } catch (e) {
      _logger.severe('Error sending SMS', e);
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getUserMessages() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('messages')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  Stream<List<Map<String, dynamic>>> getAllMessages() {
    return _firestore
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  Stream<List<Map<String, dynamic>>> getMessagesByStatus(String status) {
    return _firestore
        .collection('messages')
        .where('status', isEqualTo: status)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  Future<void> markMessageAsRead(String messageId) async {
    await _firestore.collection('messages').doc(messageId).update({
      'status': 'read',
    });
  }
} 