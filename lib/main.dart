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

final _logger = Logger();

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  _logger.i('Handling a background message: ${message.messageId}');
  
  // Show notification for background messages
  await NotificationService().showNotification(
    title: message.notification?.title ?? 'New Message',
    body: message.notification?.body ?? 'You have a new message',
    payload: message.data.toString(),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    _logger.w('Warning: .env file not found. Using default values.');
    // Set default values
    dotenv.env['APP_NAME'] = 'AIIVR Demo App';
    dotenv.env['APP_ENV'] = 'development';
  }
  
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
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8F5CFF),
            primary: const Color(0xFF8F5CFF),
            secondary: const Color(0xFF5B7CFA),
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF8F5CFF),
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFF8F5CFF).withAlpha(26),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Color(0xFF8F5CFF));
              }
              return const IconThemeData(color: Colors.grey);
            }),
          ),
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
