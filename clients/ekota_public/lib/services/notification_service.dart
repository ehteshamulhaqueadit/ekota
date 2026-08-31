import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(settings: settings);

    // Request permission for Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ekota_watchlist_channel',
      'Ekota Watchlist Alerts',
      channelDescription: 'Notifications for your watchlisted rental assets',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  static Future<void> showWatchlistAvailable(String assetName, String listingId) async {
    await showNotification(
      id: listingId.hashCode,
      title: '🔔 Product Now Available!',
      body: '"$assetName" is now available to rent on Ekota.',
      payload: listingId,
    );
  }

  static Future<void> showPriceChanged(String assetName, String listingId, String newPrice) async {
    await showNotification(
      id: listingId.hashCode + 1,
      title: '💰 Rent Price Updated',
      body: '"$assetName" rent price has changed to ৳$newPrice/day.',
      payload: listingId,
    );
  }

  static Future<void> showFunded(String assetName, String listingId) async {
    await showNotification(
      id: listingId.hashCode + 2,
      title: '🎉 Fully Funded!',
      body: '"$assetName" has reached 100% funding and will be produced!',
      payload: listingId,
    );
  }
}
