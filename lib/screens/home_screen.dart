import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/query_logging_service.dart';
import '../services/sms_service.dart';
import 'auth/login_screen.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _initializeScreens();
  }

  void _initializeScreens() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isSupervisor = authService.currentUser?.email?.contains('supervisor') ?? false;

    _screens = [
      const QueryLoggingScreen(),
      const SMSScreen(),
      const ChatScreen(),
      if (isSupervisor) const UserManagementScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isSupervisor = authService.currentUser?.email?.contains('supervisor') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AIIVR Companion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.signOut();
              if (!mounted) return;
              navigator.pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Query Logs',
          ),
          const NavigationDestination(
            icon: Icon(Icons.sms),
            label: 'SMS',
          ),
          const NavigationDestination(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          if (isSupervisor)
            const NavigationDestination(
              icon: Icon(Icons.people),
              label: 'Users',
            ),
        ],
      ),
    );
  }
}

class QueryLoggingScreen extends StatelessWidget {
  const QueryLoggingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final queryService = Provider.of<QueryLoggingService>(context);
    
    return StreamBuilder(
      stream: queryService.getRecentQueries(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final queries = snapshot.data!;
        
        return ListView.builder(
          itemCount: queries.length,
          itemBuilder: (context, index) {
            final query = queries[index];
            return ListTile(
              title: Text(query.query),
              subtitle: Text(
                'Timestamp: ${query.timestamp.toString()}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.info),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Query Details'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Query: ${query.query}'),
                          const SizedBox(height: 8),
                          Text('Time: ${query.timestamp}'),
                          const SizedBox(height: 8),
                          Text('Status: ${query.status}'),
                          if (query.response != null) ...[
                            const SizedBox(height: 8),
                            Text('Response: ${query.response}'),
                          ],
                          if (query.error != null) ...[
                            const SizedBox(height: 8),
                            Text('Error: ${query.error}'),
                          ],
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class SMSScreen extends StatelessWidget {
  const SMSScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final smsService = Provider.of<SMSService>(context);
    final phoneController = TextEditingController();
    final messageController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: messageController,
            decoration: const InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              if (phoneController.text.isEmpty ||
                  messageController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                  ),
                );
                return;
              }

              try {
                await smsService.sendMessage(
                  phoneController.text,
                  messageController.text,
                );
                phoneController.clear();
                messageController.clear();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message sent successfully')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Send SMS'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent Messages',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder(
              stream: smsService.getAllMessages(),
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
                    return ListTile(
                      title: Text(message['receiverId'] ?? ''),
                      subtitle: Text(message['message'] ?? ''),
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
        ],
      ),
    );
  }
}

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatService = Provider.of<ChatService>(context);
    final messageController = TextEditingController();

    return Column(
      children: [
        Expanded(
          child: StreamBuilder(
            stream: chatService.getMessages('system'), // Replace with actual receiver ID
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!;
              
              return ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message.author.id == 'current_user_id'; // Replace with actual user ID
                  final text = (message is types.TextMessage) ? message.text : '';
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue : Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () async {
                  if (messageController.text.isEmpty) return;

                  try {
                    await chatService.sendMessage(
                      messageController.text,
                      'system', // Replace with actual receiver ID
                    );
                    messageController.clear();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index].data();
            return ListTile(
              title: Text(user['email'] ?? 'No email'),
              subtitle: Text('Role: ${user['role'] ?? 'No role'}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  // Implement user deletion
                },
              ),
            );
          },
        );
      },
    );
  }
} 