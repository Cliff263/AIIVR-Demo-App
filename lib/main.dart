import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';

// Services
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/query_logging_service.dart';
import 'services/messaging_service.dart';
import 'services/notification_service.dart';

// Screens
import 'screens/home_screen.dart' as home;
import 'screens/auth/login_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/query_log_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/sms_screen.dart';

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final logger = Logger();
  logger.i('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();

  // Initialize Firebase Cloud Messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => QueryLoggingService()),
        ChangeNotifierProvider(create: (_) => MessagingService()),
      ],
      child: MaterialApp(
        title: 'AIIVR Demo App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        initialRoute: '/signin',
        routes: {
          '/signin': (context) => const SignInScreen(),
          '/signup': (context) => const SignUpScreen(),
          '/home': (context) => const home.HomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/queries': (context) => const QueryLogScreen(),
          '/chats': (context) => ChatListScreen(),
          '/sms': (context) => const SMSScreen(),
        },
      ),
    );
  }
}
