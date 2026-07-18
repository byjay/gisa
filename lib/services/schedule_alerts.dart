import 'qnet_schedule_service.dart';

/// 🔔 일정 알림 종류.
enum AlertType {
  regOpen, // 원서접수 시작 임박/진행중
  examSoon, // 시험일 임박
  resultSoon, // 합격발표 임박
}

extension AlertTypeInfo on AlertType {
  String get label {
    switch (this) {
      case AlertType.regOpen:
        return '원서접수';
      case AlertType.examSoon:
        return '시험일';
      case AlertType.resultSoon:
        return '합격발표';
    }
  }

  String get emoji {
    switch (this) {
      case AlertType.regOpen:
        return '📝';
      case AlertType.examSoon:
        return '✏️';
      case AlertType.resultSoon:
        return '🏆';
    }
  }
}

/// 하나의 알림 항목 (화면 표시용).
class ScheduleAlert {
  final AlertType type;
  final String certName;
  final String roundLabel;
  final String phaseLabel; // 필기/실기
  final DateTime targetDate; // 기준 날짜
  final int dDay; // 남은 일수(음수면 지남)
  final bool ongoing; // 접수 진행 중인지

  const ScheduleAlert({
    required this.type,
    required this.certName,
    required this.roundLabel,
    required this.phaseLabel,
    required this.targetDate,
    required this.dDay,
    this.ongoing = false,
  });

  String get dDayLabel {
    if (ongoing) return '진행중';
    if (dDay == 0) return 'D-DAY';
    if (dDay > 0) return 'D-$dDay';
    return 'D+${-dDay}';
  }

  /// 알림 문구.
  String get message {
    switch (type) {
      case AlertType.regOpen:
        return ongoing
            ? '$certName $phaseLabel 원서접수가 진행 중이에요. 마감 전 접수하세요!'
            : '$certName $phaseLabel 원서접수가 $dDay일 뒤 시작돼요.';
      case AlertType.examSoon:
        return dDay == 0
            ? '오늘은 $certName $phaseLabel 시험일이에요. 화이팅!'
            : '$certName $phaseLabel 시험이 $dDay일 남았어요.';
      case AlertType.resultSoon:
        return dDay == 0
            ? '오늘 $certName $phaseLabel 합격발표가 있어요!'
            : '$certName $phaseLabel 합격발표가 $dDay일 남았어요.';
    }
  }
}

/// 회차 목록으로부터 알림을 생성하는 엔진.
class ScheduleAlertEngine {
  ScheduleAlertEngine._();
  static final ScheduleAlertEngine instance = ScheduleAlertEngine._();

  /// 알림 창(며칠 전부터 알릴지).
  static const int regLeadDays = 7;
  static const int examLeadDays = 14;
  static const int resultLeadDays = 3;

  int _dday(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final t = DateTime(d.year, d.month, d.day);
    return t.difference(today).inDays;
  }

  bool _inRange(DateRange? r) {
    if (r == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final s = DateTime(r.start.year, r.start.month, r.start.day);
    final e = DateTime(r.end.year, r.end.month, r.end.day);
    return !today.isBefore(s) && !today.isAfter(e);
  }

  /// 한 종목의 회차 목록 → 활성 알림 목록.
  List<ScheduleAlert> buildAlerts(String certName, List<QnetExamRound> rounds) {
    final alerts = <ScheduleAlert>[];

    void addReg(DateRange? reg, String phase) {
      if (reg == null) return;
      if (_inRange(reg)) {
        alerts.add(
          ScheduleAlert(
            type: AlertType.regOpen,
            certName: certName,
            roundLabel: '',
            phaseLabel: phase,
            targetDate: reg.end,
            dDay: _dday(reg.end),
            ongoing: true,
          ),
        );
      } else {
        final d = _dday(reg.start);
        if (d >= 0 && d <= regLeadDays) {
          alerts.add(
            ScheduleAlert(
              type: AlertType.regOpen,
              certName: certName,
              roundLabel: '',
              phaseLabel: phase,
              targetDate: reg.start,
              dDay: d,
            ),
          );
        }
      }
    }

    void addExam(DateRange? exam, String phase) {
      if (exam == null) return;
      final d = _dday(exam.start);
      if (d >= 0 && d <= examLeadDays) {
        alerts.add(
          ScheduleAlert(
            type: AlertType.examSoon,
            certName: certName,
            roundLabel: '',
            phaseLabel: phase,
            targetDate: exam.start,
            dDay: d,
          ),
        );
      }
    }

    void addResult(DateTime? date, String phase) {
      if (date == null) return;
      final d = _dday(date);
      if (d >= 0 && d <= resultLeadDays) {
        alerts.add(
          ScheduleAlert(
            type: AlertType.resultSoon,
            certName: certName,
            roundLabel: '',
            phaseLabel: phase,
            targetDate: date,
            dDay: d,
          ),
        );
      }
    }

    for (final r in rounds) {
      addReg(r.writtenReg, '필기');
      addExam(r.writtenExam, '필기');
      addResult(r.writtenResult, '필기');
      addReg(r.practicalReg, '실기');
      addExam(r.practicalExam, '실기');
      addResult(r.finalResult, '최종');
    }

    alerts.sort((a, b) {
      if (a.ongoing != b.ongoing) return a.ongoing ? -1 : 1;
      return a.dDay.compareTo(b.dDay);
    });
    return alerts;
  }
}
