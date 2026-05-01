import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// Service de notifications hybride :
/// - **Web** : toast `SnackBar` via un `ScaffoldMessenger` global
/// - **iOS / Android / macOS / Linux** : `flutter_local_notifications`
class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  GlobalKey<ScaffoldMessengerState>? _messengerKey;

  /// Référence au `ScaffoldMessenger` racine — fournie par main.dart, sert
  /// à afficher les toasts sur web.
  void attachMessenger(GlobalKey<ScaffoldMessengerState> key) {
    _messengerKey = key;
  }

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: false,
            requestSoundPermission: true,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: false,
            requestSoundPermission: true,
          ),
        ),
      );
      // Permission runtime — Android 13+ exige une demande explicite, iOS la
      // demande au premier `show()` mais on la pré-déclenche ici pour ne pas
      // perdre la première notif.
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, sound: true);
    } catch (e) {
      debugPrint('NotificationsService.init error: $e');
    }
    _initialized = true;
  }

  /// Envoie une notif. `emoji` ajouté en préfixe du title sur natif et dans le
  /// toast web pour faciliter le scan visuel.
  Future<void> notify({
    required String title,
    String? body,
    String emoji = '⚡',
  }) async {
    if (kIsWeb) {
      _showToast(title: title, body: body, emoji: emoji);
      return;
    }
    if (!_initialized) await init();
    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '$emoji $title',
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hermes_jobs',
            'Hermes — Jobs',
            channelDescription: 'Fin de run et statut des jobs',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('NotificationsService.notify error: $e');
      // Fallback toast si la plateforme refuse.
      _showToast(title: title, body: body, emoji: emoji);
    }
  }

  void _showToast({
    required String title,
    String? body,
    required String emoji,
  }) {
    final messenger = _messengerKey?.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: HermesTokens.surface2,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesTokens.rMd),
          side: const BorderSide(color: HermesTokens.border),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: HermesText.body().copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (body != null && body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HermesText.bodySm(color: HermesTokens.textDim),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
