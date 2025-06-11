import 'package:flutter/material.dart';
import '../services/sms_service.dart';
import 'package:intl/intl.dart';

class SMSScreen extends StatefulWidget {
  const SMSScreen({super.key});
  @override
  SMSScreenState createState() => SMSScreenState();
}

class SMSScreenState extends State<SMSScreen> {
  final SMSService _smsService = SMSService();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
 
  @override
  void initState() {
    super.initState();
    _initializeMessaging();
  }

  Future<void> _initializeMessaging() async {
    await _smsService.initialize();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a phone number';
    }
    final phoneRegex = RegExp(r'^\\+263[7-8][0-9]{8}\$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Please enter a valid Zimbabwe phone number (e.g., +263779190068)';
    }
    return null;
  }

  Future<void> _sendMessage() async {
    if (_phoneController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final phoneError = _validatePhoneNumber(_phoneController.text);
    if (phoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phoneError)),
      );
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _smsService.sendMessage(
        _phoneController.text,
        _messageController.text,
      );
      _phoneController.clear();
      _messageController.clear();
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Message sent successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: \\${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8F5CFF), Color(0xFF5B7CFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '+263779190068',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.message),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send),
                      label: const Text('Send SMS'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Color(0xFF8F5CFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Recent Messages',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _smsService.getAllMessages(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: \\${snapshot.error}'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final messages = snapshot.data!;
                      return ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          DateTime? sentTime;
                          if (message['timestamp'] != null) {
                            sentTime = (message['timestamp'] is DateTime)
                                ? message['timestamp']
                                : message['timestamp'].toDate();
                          }
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Icon(Icons.sms, color: Colors.white),
                            ),
                            title: Text(message['receiverId'] ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(message['message'] ?? ''),
                                if (sentTime != null)
                                  Text(
                                    'Sent: ${DateFormat('yyyy-MM-dd HH:mm').format(sentTime)}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                            trailing: Text(
                              message['status'] == 'sent' ? '✓' : '✗',
                              style: TextStyle(
                                color: message['status'] == 'sent'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 