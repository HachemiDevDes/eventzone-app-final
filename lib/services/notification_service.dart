import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Initialize Firebase (if configured)
    try {
      if (Firebase.apps.isEmpty) {
        // TODO: The user must add google-services.json for Android. 
        // This will initialize using the default options from that file.
        await Firebase.initializeApp();
      }
    } catch (e) {
      debugPrint("Firebase not yet configured. Skipping FCM initialization: $e");
    }

    // 2. Initialize Local Notifications & Timezone
    tz.initializeTimeZones();
    AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    
    // For iOS if needed later
    DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification clicked: ${response.payload}");
        // TODO: Handle navigation when notification is tapped
      },
    );

    // 3. Request permissions for Firebase Messaging
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted push notification permission');
        
        // 4. Fetch FCM Token and save to Supabase
        String? token = await messaging.getToken();
        if (token != null) {
          await _saveTokenToSupabase(token);
        }

        // Listen for token refreshes
        messaging.onTokenRefresh.listen(_saveTokenToSupabase);

        // 5. Handle foreground FCM messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Got a message whilst in the foreground!');
          if (message.notification != null) {
            showLocalNotification(
              title: message.notification!.title ?? 'New Message',
              body: message.notification!.body ?? '',
            );
          }
        });
      }
    } catch (e) {
      debugPrint("FCM Permission request failed. Ensure Firebase is configured: $e");
    }
    
    // 6. Listen to Auth state changes to set up or tear down realtime channels
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _setupSupabaseRealtimeListeners();
      } else {
        _teardownRealtimeListeners();
      }
    });
  }

  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _connectionsChannel;

  void _teardownRealtimeListeners() {
    _messagesChannel?.unsubscribe();
    _connectionsChannel?.unsubscribe();
    _messagesChannel = null;
    _connectionsChannel = null;
  }

  void _setupSupabaseRealtimeListeners() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Prevent duplicate subscriptions
    _teardownRealtimeListeners();

    // Listen for new messages
    _messagesChannel = Supabase.instance.client
        .channel('public:messages:recipient_id=eq.${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: user.id,
          ),
          callback: (payload) async {
            final newMsg = payload.newRecord;
            
            // Only notify if unread and we are not currently on the chat screen
            // Fetch sender profile for name
            final senderRes = await Supabase.instance.client
                .from('profiles')
                .select('full_name')
                .eq('id', newMsg['sender_id'])
                .maybeSingle();
                
            final senderName = senderRes?['full_name'] ?? 'Someone';
            
            showLocalNotification(
              title: 'New Message',
              body: '$senderName sent you a message: ${newMsg['content']}',
            );
          },
        )
        .subscribe();
        
    // Listen for new connections (QR Code scans)
    _connectionsChannel = Supabase.instance.client
        .channel('public:connections:linked_profile_id=eq.${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'connections',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'linked_profile_id',
            value: user.id,
          ),
          callback: (payload) {
            final newConn = payload.newRecord;
            final name = newConn['name'] ?? 'Someone';
            showLocalNotification(
              title: 'New Connection!',
              body: '$name connected with you via QR code.',
            );
          },
        )
        .subscribe();
  }

  Future<void> _saveTokenToSupabase(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      // Upsert the token to the user_fcm_tokens table
      await Supabase.instance.client.from('user_fcm_tokens').upsert(
        {
          'user_id': user.id,
          'token': token,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );
      debugPrint("FCM token saved to Supabase.");
    } catch (e) {
      debugPrint("Error saving FCM token to Supabase: $e");
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel', // id
      'High Importance Notifications', // name
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
        
    await _localNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch % 100000, // random id
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> scheduleDailyStreakNotifications() async {
    await _localNotificationsPlugin.cancel(id: 909);
    await _localNotificationsPlugin.cancel(id: 911);

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    
    // 9 PM Notification
    tz.TZDateTime scheduledDate9PM =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 21);
    if (scheduledDate9PM.isBefore(now)) {
      scheduledDate9PM = scheduledDate9PM.add(Duration(days: 1));
    }

    // 11 AM Notification
    tz.TZDateTime scheduledDate11AM =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 11);
    if (scheduledDate11AM.isBefore(now)) {
      scheduledDate11AM = scheduledDate11AM.add(Duration(days: 1));
    }

    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'daily_streak_channel',
      'Daily Streak Reminder',
      channelDescription: 'Reminds you to keep your networking streak alive',
      importance: Importance.max,
      priority: Priority.high,
    );

    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Schedule 9 PM
    await _localNotificationsPlugin.zonedSchedule(
      id: 909,
      title: 'Keep your streak alive! 🔥',
      body: 'Remember to add at least one contact today to keep your daily streak going.',
      scheduledDate: scheduledDate9PM,
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Schedule 11 AM
    await _localNotificationsPlugin.zonedSchedule(
      id: 911,
      title: 'Don\'t lose your streak! 🔥',
      body: 'Connect with someone new today to keep your streak going strong.',
      scheduledDate: scheduledDate11AM,
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}


// Background FCM handler (must be a top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}
