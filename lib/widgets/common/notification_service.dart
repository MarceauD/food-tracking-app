// lib/helpers/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Gérer l'action du clic sur la notif quand l'app est en arrière-plan
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialisation pour Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Utilise votre icône d'app

    // Initialisation pour iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      // Ajout pour gérer le clic sur une notification quand l'app est terminée
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    tz.initializeTimeZones(); // Initialise les fuseaux horaires
  }

  Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> showOneTimeNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _notificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'one_time_channel', // Un nouveau canal pour ces notifications
          'Notifications Ponctuelles',
          channelDescription: 'Notifications pour des événements spécifiques.',
          importance: Importance.max,
          priority: Priority.high,
          
        ),
      ),
    );
  }

  Future<void> scheduleDailyMorningReminder() async {
    await _notificationsPlugin.zonedSchedule(
      0, // ID de la notification
      'C\'est l\'heure de commencer !',
      'Pensez à enregistrer votre petit-déjeuner pour bien démarrer la journée.',
      _nextInstanceOfTime(8, 30), 
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
// Heure de la notification (8h30)
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'morning_reminder',
          'Rappel Matinal',
          channelDescription: 'Rappel pour enregistrer le petit-déjeuner',
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

 
  // Calcule la prochaine occurrence de l'heure spécifiée
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> scheduleWeeklyReportReminder() async {
    await _notificationsPlugin.zonedSchedule(
      1, // ID 1 pour cette nouvelle notification, différent du premier
      'C\'est l\'heure du bilan !',
      'N\'oubliez pas d\'envoyer votre rapport hebdomadaire à votre coach.',
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      _nextInstanceOfDayAndTime(DateTime.sunday, 20, 00), // On programme pour le dimanche à 20h00
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_report_channel', // ID de canal unique
          'Rappels Hebdomadaires',
          channelDescription: 'Rappel pour envoyer le bilan de la semaine',
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // Pour que ça se répète toutes les semaines le même jour à la même heure
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, 
    );
  }

  Future<void> cancelWeeklyReportReminder() async {
    await _notificationsPlugin.cancel(1); // 1 = l’ID utilisé pour la notif hebdo
  } 

  // --- NOUVELLE MÉTHODE D'AIDE POUR CALCULER LE PROCHAIN JOUR DE LA SEMAINE ---
  tz.TZDateTime _nextInstanceOfDayAndTime(int day, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // On avance jour par jour jusqu'à tomber sur le bon jour de la semaine (ex: dimanche)
    while (scheduledDate.weekday != day) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    // Si la date est déjà passée pour aujourd'hui, on programme pour la semaine suivante
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }
    return scheduledDate;
  }
}