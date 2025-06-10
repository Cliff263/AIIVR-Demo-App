import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

@pragma('vm:entry-point')
Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
  // Handle notification action
  debugPrint('Action received: ${receivedAction.toMap()}');
}

@pragma('vm:entry-point')
Future<void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {
  // Handle notification creation
  debugPrint('Notification created: ${receivedNotification.toMap()}');
}

@pragma('vm:entry-point')
Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
  // Handle notification display
  debugPrint('Notification displayed: ${receivedNotification.toMap()}');
}

@pragma('vm:entry-point')
Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
  // Handle notification dismissal
  debugPrint('Notification dismissed: ${receivedAction.toMap()}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null, // null means use default app icon
      [
        NotificationChannel(
          channelKey: 'basic_channel',
          channelName: 'Basic Notifications',
          channelDescription: 'Basic notification channel',
          defaultColor: Colors.blue,
          importance: NotificationImportance.High,
          channelShowBadge: true,
        ),
        NotificationChannel(
          channelKey: 'chat_channel',
          channelName: 'Chat Notifications',
          channelDescription: 'Chat notification channel',
          defaultColor: Colors.green,
          importance: NotificationImportance.High,
          channelShowBadge: true,
        ),
      ],
    );

    // Request permission for notifications
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    // Listen to notification events
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String channelKey = 'basic_channel',
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: channelKey,
        title: title,
        body: body,
        payload: {'data': payload ?? ''},
      ),
    );
  }

  Future<void> showChatNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await showNotification(
      title: title,
      body: body,
      payload: payload,
      channelKey: 'chat_channel',
    );
  }

  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }
} 