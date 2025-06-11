import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/query_logging_service.dart';
import '../services/sms_service.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late List<Widget> _screens;
  bool _isSupervisor = false;

  @override
  void initState() {
    super.initState();
    _initializeScreens();
  }

  Future<void> _initializeScreens() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userRole = await authService.getUserRole();
    setState(() {
      _isSupervisor = userRole == UserRole.supervisor;
      _screens = [
        const QueryLoggingScreen(),
        const SMSScreen(),
        const ChatScreen(),
        if (_isSupervisor) const UserManagementScreen(),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userName = authService.currentUser?.email?.split('@').first ?? 'User';
    final userRole = _isSupervisor ? 'Supervisor' : 'Agent';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8F5CFF), Color(0xFF5B7CFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: TopNavbar(
            userName: userName,
            userRole: userRole,
            onLogout: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.signOut();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/signin');
            },
            onProfileTap: () {},
            isOnline: authService.currentUser != null,
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: MetricsCard(isSupervisor: _isSupervisor),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 8,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _screens[_currentIndex],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF8F5CFF),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.1 * 255).toInt()),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            elevation: 0,
            height: 65,
            indicatorColor: Colors.white.withAlpha((0.2 * 255).toInt()),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.history_outlined, color: Colors.white),
                selectedIcon: Icon(Icons.history, color: Colors.white),
                label: 'Queries',
              ),
              const NavigationDestination(
                icon: Icon(Icons.sms_outlined, color: Colors.white),
                selectedIcon: Icon(Icons.sms, color: Colors.white),
                label: 'SMS',
              ),
              const NavigationDestination(
                icon: Icon(Icons.chat_outlined, color: Colors.white),
                selectedIcon: Icon(Icons.chat, color: Colors.white),
                label: 'Chat',
              ),
            ],
          ),
        ),
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
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    final bool isOnline = userId != null;
    final DateTime? lastSeen = !isOnline ? DateTime.now().subtract(const Duration(minutes: 5)) : null; // Placeholder for last seen
    String statusText;
    if (isOnline) {
      statusText = 'Online';
    } else if (lastSeen != null) {
      statusText = 'Last seen: ${DateFormat('yyyy-MM-dd HH:mm').format(lastSeen)}';
    } else {
      statusText = 'Offline';
    }
    // For demo, use a chat room ID based on userId or a default
    final chatRoomId = userId ?? 'system';
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(
                statusText,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder(
            stream: chatService.getMessages(chatRoomId),
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
                  final isMe = userId != null && message.author.id == userId;
                  final text = (message is types.TextMessage) ? message.text : '';
                  final int? createdAt = (message is types.TextMessage) ? message.createdAt : null;
                  final DateTime? msgTime = createdAt != null ? DateTime.fromMillisecondsSinceEpoch(createdAt) : null;
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            text,
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black,
                            ),
                          ),
                          if (msgTime != null)
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm').format(msgTime),
                              style: const TextStyle(fontSize: 10, color: Colors.white70),
                            ),
                        ],
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
                  if (messageController.text.isEmpty || userId == null) return;

                  try {
                    await chatService.sendMessage(
                      chatRoomId,
                      messageController.text,
                    );
                    messageController.clear();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
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

class TopNavbar extends StatelessWidget implements PreferredSizeWidget {
  final String userName;
  final String userRole;
  final VoidCallback onLogout;
  final VoidCallback onProfileTap;
  final bool isOnline;

  const TopNavbar({
    super.key,
    required this.userName,
    required this.userRole,
    required this.onLogout,
    required this.onProfileTap,
    this.isOnline = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8F5CFF), Color(0xFF5B7CFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 36, left: 16, right: 16, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onProfileTap,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: AssetImage('assets/avatar_placeholder.png'), // Replace with user image if available
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                userRole.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: onLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(90);
}

class MetricsCard extends StatelessWidget {
  final bool isSupervisor;
  const MetricsCard({super.key, required this.isSupervisor});

  @override
  Widget build(BuildContext context) {
    final queryService = Provider.of<QueryLoggingService>(context);
    final chatService = Provider.of<ChatService>(context);
    final smsService = Provider.of<SMSService>(context);
    
    if (isSupervisor) {
      // Supervisor metrics: online agents, queries breakdown, active chats
      return StreamBuilder(
        stream: queryService.getAllQueries(),
        builder: (context, snapshot) {
          final queries = snapshot.data ?? [];
          final pending = queries.where((q) => q.status == QueryStatus.pending).length;
          final assigned = queries.where((q) => q.status == QueryStatus.assigned).length;
          final resolved = queries.where((q) => q.status == QueryStatus.resolved).length;
          return StreamBuilder(
            stream: queryService.getAgents(),
            builder: (context, agentSnap) {
              final agents = agentSnap.data ?? [];
              final onlineAgents = agents.where((a) => a['isOnline'] == true).length;
              return StreamBuilder(
                stream: chatService.getUserChats(),
                builder: (context, chatSnap) {
                  final chats = chatSnap.data ?? [];
                  return _MetricsLayout(
                    metrics: [
                      _MetricItem(label: 'Online Agents', value: onlineAgents.toString(), icon: Icons.people, color: Colors.green),
                      _MetricItem(label: 'Queries', value: queries.length.toString(), icon: Icons.history, color: Colors.orange),
                      _MetricItem(label: 'Pending', value: pending.toString(), icon: Icons.pending, color: Colors.amber),
                      _MetricItem(label: 'Assigned', value: assigned.toString(), icon: Icons.assignment, color: Colors.blue),
                      _MetricItem(label: 'Resolved', value: resolved.toString(), icon: Icons.check_circle, color: Colors.green),
                      _MetricItem(label: 'Active Chats', value: chats.length.toString(), icon: Icons.chat, color: Colors.purple),
                    ],
                  );
                },
              );
            },
          );
        },
      );
    } else {
      // Agent metrics: assigned queries, active chats, SMS sent/received
      return StreamBuilder(
        stream: queryService.getAssignedQueries(),
        builder: (context, snapshot) {
          final queries = snapshot.data ?? [];
          final pending = queries.where((q) => q.status == QueryStatus.pending).length;
          final assigned = queries.where((q) => q.status == QueryStatus.assigned).length;
          final inProgress = queries.where((q) => q.status == QueryStatus.inProgress).length;
          final resolved = queries.where((q) => q.status == QueryStatus.resolved).length;
          return StreamBuilder(
            stream: chatService.getUserChats(),
            builder: (context, chatSnap) {
              final chats = chatSnap.data ?? [];
              return StreamBuilder(
                stream: smsService.getUserMessages(),
                builder: (context, smsSnap) {
                  final sms = smsSnap.data ?? [];
                  final sent = sms.where((m) => m['status'] == 'delivered').length;
                  final received = sms.where((m) => m['status'] == 'received').length;
                  return _MetricsLayout(
                    metrics: [
                      _MetricItem(label: 'Assigned', value: assigned.toString(), icon: Icons.assignment, color: Colors.blue),
                      _MetricItem(label: 'Pending', value: pending.toString(), icon: Icons.pending, color: Colors.amber),
                      _MetricItem(label: 'In Progress', value: inProgress.toString(), icon: Icons.work, color: Colors.purple),
                      _MetricItem(label: 'Resolved', value: resolved.toString(), icon: Icons.check_circle, color: Colors.green),
                      _MetricItem(label: 'Active Chats', value: chats.length.toString(), icon: Icons.chat, color: Colors.purple),
                      _MetricItem(label: 'SMS Sent', value: sent.toString(), icon: Icons.sms, color: Colors.green),
                      _MetricItem(label: 'SMS Received', value: received.toString(), icon: Icons.sms_failed, color: Colors.red),
                    ],
                  );
                },
              );
            },
          );
        },
      );
    }
  }
}

class _MetricsLayout extends StatelessWidget {
  final List<_MetricItem> metrics;
  const _MetricsLayout({required this.metrics});
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 24,
          runSpacing: 12,
          children: metrics,
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricItem({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: color.withAlpha((0.1 * 255).toInt()),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
} 