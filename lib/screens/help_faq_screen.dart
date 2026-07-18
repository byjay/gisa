import 'package:flutter/material.dart';

/// ❓ 도움말 · 자주 묻는 질문(FAQ) 화면
/// 사용자 지원(CS) 셀프서비스 — 설정 화면에서 진입.
class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  static const List<_FaqSection> _sections = [
    _FaqSection('시작하기', Icons.rocket_launch_rounded, [
      _Faq(
        '볼트쌤은 어떤 앱인가요?',
        '전기기사·전기공사기사·소방설비기사 등 국가기술자격 시험을 준비하는 분들을 위한 '
            '올인원 학습 앱입니다. 기출문제 풀이, AI 튜터, 암기법, 합격 예측, '
            '학습 통계까지 한 곳에서 제공합니다.',
      ),
      _Faq(
        '자격증 종목을 바꾸고 싶어요.',
        '설정 화면 상단의 "자격증 트랙" 메뉴에서 언제든 다른 종목으로 변경할 수 있습니다. '
            '종목별 학습 기록은 각각 따로 저장되므로 안심하고 전환하세요.',
      ),
      _Faq(
        '비전공자인데 어디서부터 시작해야 하나요?',
        '학습 탭의 "왕초보 로드맵"을 추천합니다. 지식 0에서 합격까지 단계별로 '
            '무엇을 공부할지 안내해 드립니다. 먼저 15문제 진단고사를 풀면 '
            '홈 화면에서 나만의 합격 예측 점수도 확인할 수 있습니다.',
      ),
    ]),
    _FaqSection('문제 풀이 · 시험', Icons.quiz_rounded, [
      _Faq(
        '연습 모드와 실전 모드는 무엇이 다른가요?',
        '연습 모드는 문제를 풀면서 바로 정답과 해설을 볼 수 있습니다. '
            '실전 모드는 실제 시험처럼 제출 전까지 정답이 공개되지 않으며, '
            '중도 이탈 시 확인 창이 표시됩니다.',
      ),
      _Faq(
        '오답노트는 어떻게 만들어지나요?',
        '문제를 틀리면 자동으로 오답노트에 저장됩니다. '
            '학습 탭의 "오답 집중"에서 틀린 문제만 모아 다시 풀 수 있고, '
            '반복 분석에서 취약 유형도 확인할 수 있습니다.',
      ),
      _Faq(
        '문제에 오류가 있는 것 같아요.',
        '문제 풀이 화면 우측 상단 메뉴에서 "오류 신고"를 눌러 주세요. '
            '신고 내용은 검토 후 다음 업데이트에 반영됩니다.',
      ),
    ]),
    _FaqSection('합격 예측 · 통계', Icons.insights_rounded, [
      _Faq(
        '합격 예측 점수는 어떻게 계산되나요?',
        '기출문제의 토픽별 출제 비중과 회원님의 실제 정답률을 결합해 계산합니다. '
            '아직 풀지 않은 토픽은 사전 확률(35%)로 보수적으로 추정하며, '
            '풀이 수가 늘어날수록 예측이 정확해집니다. '
            '평균 60점 이상 + 전 과목 40점 이상이면 합격 판정입니다. '
            '홈 화면 예측 카드의 ⓘ 버튼에서도 자세한 설명을 볼 수 있습니다.',
      ),
      _Faq(
        '예측 점수가 실제 시험 점수와 같은가요?',
        '아니요, 학습 참고용 추정치입니다. 풀이 이력이 많을수록 정확해지지만 '
            '실제 시험 난이도·컨디션에 따라 달라질 수 있으니 '
            '과락 경보와 처방전(약점 토픽)을 중심으로 활용하세요.',
      ),
    ]),
    _FaqSection('AI 튜터', Icons.smart_toy_rounded, [
      _Faq(
        'AI 튜터를 쓰려면 무엇이 필요한가요?',
        'AI 튜터는 본인의 Cerebras API 키(무료 발급 가능)를 설정 화면에 입력하면 '
            '사용할 수 있습니다. 키는 회원님의 기기에만 저장되며 외부로 전송되지 않습니다.',
      ),
      _Faq(
        'AI 답변은 항상 정확한가요?',
        'AI 답변은 학습 참고용이며 틀릴 수 있습니다. 중요한 법규·수치·공식은 '
            '반드시 앱의 시험정보와 공식 자료(큐넷 등)로 재확인하세요. '
            '실전 모드 시험 중에는 공정성을 위해 AI 튜터 사용이 제한됩니다.',
      ),
    ]),
    _FaqSection('데이터 · 백업', Icons.backup_rounded, [
      _Faq(
        '학습 기록은 어디에 저장되나요?',
        '모든 학습 기록은 회원님의 기기에만 저장됩니다(로컬 저장). '
            '서버로 전송되지 않으므로 개인정보 걱정 없이 사용할 수 있습니다.',
      ),
      _Faq(
        '기기를 바꾸면 기록을 옮길 수 있나요?',
        '설정 → 백업 카드에서 "내보내기"로 백업 파일을 만들어 새 기기로 전달한 뒤 '
            '"가져오기"로 복원하면 됩니다. 백업 파일에는 무결성 검증(체크섬)이 포함되어 '
            '손상된 파일은 자동으로 거부됩니다. 또한 7일마다 자동 백업이 생성됩니다.',
      ),
      _Faq(
        '앱을 삭제하면 기록도 사라지나요?',
        '네, 로컬 저장 방식이므로 앱 삭제 시 기록이 함께 삭제됩니다. '
            '삭제 전 반드시 설정에서 백업 파일을 내보내 주세요.',
      ),
    ]),
    _FaqSection('알림 · 설정', Icons.notifications_active_rounded, [
      _Faq(
        '학습 리마인더 알림이 오지 않아요.',
        '설정에서 알림이 켜져 있는지 확인한 뒤, 기기 설정 → 앱 → 볼트쌤 → 알림 '
            '권한이 허용되어 있는지 확인해 주세요. 일부 기기는 배터리 최적화 예외 '
            '등록이 필요할 수 있습니다.',
      ),
      _Faq(
        '글자가 너무 작아요 / 애니메이션을 줄이고 싶어요.',
        '설정 화면에서 "텍스트 크기" 슬라이더와 "애니메이션 줄이기" 토글을 '
            '제공합니다. 기기 시스템의 글꼴 크기 설정도 함께 반영됩니다.',
      ),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('도움말 · FAQ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: cs.primaryContainer.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.support_agent_rounded, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '자주 묻는 질문을 모았습니다.\n문제 오류는 풀이 화면의 "오류 신고"를 이용해 주세요.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final section in _sections) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                child: Row(
                  children: [
                    Icon(section.icon, size: 18, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < section.items.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ExpansionTile(
                        title: Text(
                          section.items[i].q,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          14,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.items[i].a,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.55,
                              color: cs.onSurface.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _FaqSection {
  final String title;
  final IconData icon;
  final List<_Faq> items;
  const _FaqSection(this.title, this.icon, this.items);
}

class _Faq {
  final String q;
  final String a;
  const _Faq(this.q, this.a);
}
