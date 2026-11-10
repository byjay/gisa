import 'package:cert_study_tracker/services/qnet_schedule_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// [P1-A/T5] Q-Net HTML 파서 회귀 테스트.
///
/// 이 서비스는 제3자 CORS 프록시를 경유해 받아온, 신뢰할 수 없는 외부
/// HTML을 파싱한다. 정상 케이스뿐 아니라, 위조/오염된 날짜(비합리적 연도)가
/// 섞였을 때 해당 값만 안전하게 폐기되는지 검증한다.
void main() {
  final service = QnetScheduleService.instance;
  final thisYear = DateTime.now().year;

  String tableHtml(List<List<String>> rows) {
    final rowsHtml = rows
        .map((cells) => '<tr>${cells.map((c) => '<td>$c</td>').join()}</tr>')
        .join();
    return '<html><body>시험일정<table>$rowsHtml</table></body></html>';
  }

  group('QnetScheduleService 파서', () {
    test('정상 HTML에서 회차 정보를 추출한다', () {
      final html = tableHtml([
        [
          '2026년 정기 기사 1회',
          '$thisYear.01.12 ~ $thisYear.01.15',
          '$thisYear.02.07',
          '$thisYear.03.11',
          '$thisYear.04.06 ~ $thisYear.04.09',
          '$thisYear.05.09',
          '$thisYear.06.10',
        ],
      ]);
      final rounds = service.parseScheduleTableForTest(html);
      expect(rounds.length, 1);
      expect(rounds.first.label, '2026년 정기 기사 1회');
      expect(rounds.first.writtenReg, isNotNull);
      expect(rounds.first.writtenExam, isNotNull);
    });

    test('"시험일정" 헤더나 <table>이 없으면 빈 목록을 반환한다', () {
      expect(service.parseScheduleTableForTest('<html>내용 없음</html>'), isEmpty);
      expect(service.parseScheduleTableForTest('시험일정 그런데 표는 없음'), isEmpty);
    });

    test('헤더 행(<th> 포함)은 결과에서 제외된다', () {
      final html =
          '<html><body>시험일정<table>'
          '<tr><th>구분</th><th>필기원서접수</th><th>필기시험</th><th>필기합격발표</th></tr>'
          '<tr><td>1회</td><td>$thisYear.01.01 ~ $thisYear.01.05</td>'
          '<td>$thisYear.02.01</td><td>$thisYear.03.01</td></tr>'
          '</table></body></html>';
      final rounds = service.parseScheduleTableForTest(html);
      expect(rounds.length, 1);
      expect(rounds.first.label, '1회');
    });

    test('[S2] 비합리적 연도(1900, 2099)가 섞인 날짜는 폐기되어 크래시 없이 처리된다', () {
      // 위조된 날짜(연도 1900) — 실제 프록시 오염을 흉내낸다.
      final html = tableHtml([
        ['위조회차', '1900.01.01 ~ 1900.01.05', '2099.12.31', '', '', '', ''],
      ]);
      final rounds = service.parseScheduleTableForTest(html);
      expect(rounds.length, 1);
      // 비합리적 연도의 날짜는 모두 걸러져 null이 되어야 한다.
      expect(rounds.first.writtenReg, isNull);
      expect(rounds.first.writtenExam, isNull);
    });

    test('정상 날짜와 위조 날짜가 같은 셀에 섞이면 정상 날짜만 채택된다', () {
      final html = tableHtml([
        [
          '혼합회차',
          '1900.01.01 ~ $thisYear.01.15', // 첫 날짜는 위조, 둘째는 정상
          '',
          '',
          '',
          '',
          '',
        ],
      ]);
      final rounds = service.parseScheduleTableForTest(html);
      expect(rounds.length, 1);
      // 위조 날짜가 제거된 뒤 남은 유효 날짜 1개만 있으므로
      // DateRange(start, start) 형태(단일일)가 되어야 한다.
      final range = rounds.first.writtenReg;
      expect(range, isNotNull);
      expect(range!.start.year, thisYear);
    });

    test('label이 빈 문자열인 행은 건너뛴다', () {
      final html = tableHtml([
        ['', '$thisYear.01.01', '', '', '', '', ''],
      ]);
      expect(service.parseScheduleTableForTest(html), isEmpty);
    });
  });
}
