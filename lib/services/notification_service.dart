import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'schedule_alerts.dart';

/// 🔔 로컬 푸시 알림 서비스 — 앱을 꺼둬도 시험 일정을 놓치지 않도록.
///
/// - 매일 아침 학습 리마인드
/// - 시험/원서접수/합격발표 D-day 알림 (실제 기기 알림, 앱 실행 불필요)
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'cert_study_channel';
  static const _channelName = '자격증 학습 알림';
  static const _channelDesc = '시험 일정 및 학습 리마인드 알림';

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      // 한국 표준시로 고정 (앱 사용자층이 KST 기준)
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (e) {
      if (kDebugMode) debugPrint('timezone init 실패: $e');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _ready = true;
  }

  /// 알림 권한 요청 (Android 13+)
  Future<bool> requestPermission() async {
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return granted ?? false;
  }

  Future<bool> hasPermission() async {
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.areNotificationsEnabled();
    return granted ?? false;
  }

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
  );

  /// 매일 정해진 시각(기본 오전 9시)에 학습 리마인드.
  Future<void> scheduleDailyReminder({
    int hour = 9,
    int minute = 0,
    String title = '⚡ 오늘도 합격을 향해!',
    String body = '오늘의 학습 목표를 시작해볼까요? 잠깐 문제 3개만 풀어봐요.',
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      900001, // 고정 ID — 매일 리마인드 전용
      title,
      body,
      scheduled,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() => _plugin.cancel(900001);

  /// 시험 일정 알림 목록을 실제 기기 알림으로 예약.
  /// D-day 당일 오전 9시에 발송되도록 스케줄링(이미 지난 시각이면 스킵).
  Future<void> scheduleExamAlerts(List<ScheduleAlert> alerts) async {
    await init();
    // 기존 예약된 시험 알림(ID 범위 100000~199999) 초기화 후 재예약
    for (var i = 100000; i < 100000 + alerts.length + 20; i++) {
      await _plugin.cancel(i);
    }
    final now = tz.TZDateTime.now(tz.local);
    var id = 100000;
    for (final a in alerts) {
      final target = a.targetDate;
      var when = tz.TZDateTime(
        tz.local,
        target.year,
        target.month,
        target.day,
        9,
      );
      if (when.isBefore(now)) continue;
      await _plugin.zonedSchedule(
        id++,
        '${a.type.emoji} ${a.certName} ${a.dDayLabel}',
        a.message,
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// 즉시 테스트 알림 (설정 화면 "알림 테스트" 버튼용)
  Future<void> showTestNotification() async {
    await init();
    await _plugin.show(
      999999,
      '🔔 알림 테스트',
      '알림이 정상적으로 도착했어요! 이제 시험 일정을 놓치지 않아요.',
      _details,
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
