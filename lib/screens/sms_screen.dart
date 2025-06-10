import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/sms_service.dart';
import '../services/auth_service.dart';

class SMSScreen extends StatefulWidget {
  const SMSScreen({super.key});
  @override
  SMSScreenState createState() => SMSScreenState();
}

class SMSScreenState extends State<SMSScreen> {
  final SMSService _smsService = SMSService();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

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
    // Basic validation for Zimbabwe phone numbers
    final phoneRegex = RegExp(r'^\+263[7-8][0-9]{8}$');
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
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isSupervisor = authService.currentUser?.email?.contains('supervisor') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => _buildFilterSheet(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
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
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  validator: _validatePhoneNumber,
                  onChanged: (value) {
                    if (value.length == 9 && !value.startsWith('+263')) {
                      _phoneController.text = '+263$value';
                      _phoneController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _phoneController.text.length),
                      );
                    }
                  },
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
                  ),
                ),
              ],
            ),
          ),
          if (_selectedStatus != null || _startDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_selectedStatus != null)
                    Chip(
                      label: Text('Status: $_selectedStatus'),
                      onDeleted: () => setState(() => _selectedStatus = null),
                    ),
                  if (_startDate != null && _endDate != null)
                    Chip(
                      label: Text(
                        'Date: ${_startDate!.toString().split(' ')[0]} - ${_endDate!.toString().split(' ')[0]}',
                      ),
                      onDeleted: () => setState(() {
                        _startDate = null;
                        _endDate = null;
                      }),
                    ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _selectedStatus != null
                  ? _smsService.getMessagesByStatus(_selectedStatus!)
                  : isSupervisor
                      ? _smsService.getAllMessages()
                      : _smsService.getUserMessages(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages found'));
                }

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text('To: ${message['phoneNumber']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(message['message']),
                            Text('Status: ${message['status']}'),
                            if (message['error'] != null)
                              Text(
                                'Error: ${message['error']}',
                                style: const TextStyle(color: Colors.red),
                              ),
                            Text(
                              'Time: ${message['timestamp']?.toDate().toString().split('.')[0] ?? 'N/A'}',
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () {
                          if (message['status'] != 'read') {
                            _smsService.markMessageAsRead(message['id']);
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Filter Messages',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'sending', child: Text('Sending')),
              DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
              DropdownMenuItem(value: 'failed', child: Text('Failed')),
              DropdownMenuItem(value: 'read', child: Text('Read')),
            ],
            onChanged: (value) {
              setState(() => _selectedStatus = value);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _selectDateRange();
              Navigator.pop(context);
            },
            child: const Text('Select Date Range'),
          ),
        ],
      ),
    );
  }
} 