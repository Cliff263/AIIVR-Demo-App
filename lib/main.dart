import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Services
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/query_logging_service.dart';
import 'services/messaging_service.dart';
import 'services/notification_service.dart';
import 'services/sms_service.dart';

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
  
  // Show notification for background messages
  await NotificationService().showNotification(
    title: message.notification?.title ?? 'New Message',
    body: message.notification?.body ?? 'You have a new message',
    payload: message.data.toString(),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  await Hive.initFlutter();

  // Initialize Firebase Cloud Messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  // Initialize messaging service
  final messagingService = MessagingService();
  await messagingService.initialize();
  
  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    NotificationService().showNotification(
      title: message.notification?.title ?? 'New Message',
      body: message.notification?.body ?? 'You have a new message',
      payload: message.data.toString(),
    );
  });

  // Handle notification clicks when app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    Logger().i('Message opened from background: ${message.data}');
  });
  
  runApp(MyApp(messagingService: messagingService));
}

class MyApp extends StatelessWidget {
  final MessagingService messagingService;
  
  const MyApp({super.key, required this.messagingService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => QueryLoggingService()),
        ChangeNotifierProvider.value(value: messagingService),
        ChangeNotifierProvider(create: (_) => SMSService()),
      ],
      child: MaterialApp(
        title: 'AIIVR Demo App',
        navigatorKey: messagingService.navigatorKey,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (authService.isAuthenticated) {
          return const home.HomeScreen();
        }
        return const SignInScreen();
      },
    );
  }
}
