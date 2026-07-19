import 'package:flutter_test/flutter_test.dart';

import 'package:cert_study_tracker/services/tutor_behavior.dart';
import 'package:cert_study_tracker/widgets/tutor_avatar.dart';
import 'package:cert_study_tracker/widgets/tutor_coach.dart';

void main() {
  group('캐릭터 × 100 행동패턴 뱅크', () {
    // 캐릭터 목록은 튜터 프로필을 단일 진실 원천으로 삼아 파생한다.
    final tutorIds = tutorProfiles.map((p) => p.id).toList();

    test('등록 캐릭터는 튜터 프로필과 정확히 일치한다', () {
      expect(
        TutorBehaviorBank.banks.keys.toSet(),
        tutorProfiles.map((p) => p.id).toSet(),
        reason: '행동패턴 뱅크와 튜터 프로필 캐릭터가 일치해야 한다',
      );
      expect(tutorIds, contains('volt'), reason: 'volt(볼트쌤) 대표 캐릭터가 포함되어야 한다');
    });

    test('캐릭터마다 행동패턴이 100개 이상이다', () {
      for (final id in tutorIds) {
        final count = TutorBehaviorBank.countOf(id);
        expect(
          count,
          greaterThanOrEqualTo(100),
          reason: '$id 캐릭터의 행동패턴은 100개 이상이어야 한다 (현재 $count개)',
        );
      }
    });

    test('모든 CoachSituation(27종)을 캐릭터별로 빠짐없이 커버한다', () {
      for (final id in tutorIds) {
        final bank = TutorBehaviorBank.banks[id]!;
        for (final s in CoachSituation.values) {
          expect(
            bank.containsKey(s) && bank[s]!.isNotEmpty,
            isTrue,
            reason: '$id 캐릭터에 $s 상황 패턴이 없다',
          );
        }
      }
    });

    test('멘트는 모두 비어있지 않고 캐릭터 내에서 중복이 없다', () {
      for (final id in tutorIds) {
        final all = <String>[];
        for (final list in TutorBehaviorBank.banks[id]!.values) {
          for (final m in list) {
            expect(m.trim(), isNotEmpty, reason: '$id 캐릭터에 빈 멘트 존재');
            all.add(m);
          }
        }
        expect(all.toSet().length, all.length, reason: '$id 캐릭터 내 중복 멘트 존재');
      }
    });

    test('pick()은 해당 상황의 패턴 중 하나를 반환한다', () {
      for (final id in tutorIds) {
        for (final s in CoachSituation.values) {
          final m = TutorBehaviorBank.pick(id, s);
          expect(m, isNotNull);
          expect(TutorBehaviorBank.banks[id]![s], contains(m));
        }
      }
    });

    test('미등록 캐릭터는 null을 반환해 공용 멘트로 안전하게 폴백한다', () {
      expect(
        TutorBehaviorBank.pick('unknown', CoachSituation.encourage),
        isNull,
      );
      // 공용 멘트 폴백도 항상 존재
      final fallback = TutorMents.pick(CoachSituation.encourage);
      expect(fallback.trim(), isNotEmpty);
    });

    test('공용 멘트(TutorMents)도 전 상황 × 3수준을 커버한다', () {
      for (final s in CoachSituation.values) {
        for (var level = 0; level < 3; level++) {
          expect(TutorMents.pick(s, level: level).trim(), isNotEmpty);
        }
      }
    });
  });
}
