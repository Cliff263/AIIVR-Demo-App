import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatService = Provider.of<ChatService>(context);
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
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: chatService.getUserChats(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: \\${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final chats = snapshot.data!;
            if (chats.isEmpty) {
              return const Center(child: Text('No chats yet'));
            }

            return ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 6,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.chat, color: Colors.white),
                    ),
                    title: Text('Chat \\${index + 1}', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(chat['lastMessage'] ?? 'No messages yet'),
                    trailing: chat['lastMessageTime'] != null
                        ? Text(
                            _formatTimestamp(chat['lastMessageTime']),
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatRoomScreen(chatId: chat['id']),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '\\${date.hour}:\\${date.minute.toString().padLeft(2, '0')}';
  }
} 