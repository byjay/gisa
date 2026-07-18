import 'package:flutter/material.dart';

/// 📜 법적 고지 — 개인정보처리방침 / 이용약관 / AI 고지 (Play Store 필수)
class LegalScreen extends StatelessWidget {
  final int initialTab; // 0=개인정보 1=약관 2=AI고지
  const LegalScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('법적 고지'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '개인정보'),
              Tab(text: '이용약관'),
              Tab(text: 'AI 고지'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _doc(context, _privacy),
            _doc(context, _terms),
            _doc(context, _aiNotice),
          ],
        ),
      ),
    );
  }

  Widget _doc(BuildContext context, List<(String, String)> sections) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        for (final (title, body) in sections) ...[
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              height: 1.65,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 18),
        ],
        Text(
          '시행일: 2025년 1월 1일 · 문의: certstudytracker@gmail.com',
          style: TextStyle(
            fontSize: 11.5,
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  // ── 개인정보처리방침 ──────────────────────────────────
  static const List<(String, String)> _privacy = [
    (
      '1. 수집하는 정보',
      'Cert Study Tracker(이하 "앱")는 회원가입 없이 사용할 수 있으며, 학습 기록(문제 풀이 내역, 학습 시간, 오답 노트, 설정값)은 모두 사용자 기기 내부에만 저장됩니다. 앱은 이름·이메일·전화번호 등 개인 식별 정보를 서버로 전송하거나 수집하지 않습니다.',
    ),
    (
      '2. AI 튜터 이용 시 처리되는 정보',
      'AI 튜터 기능 사용 시, 사용자가 입력한 질문 텍스트가 사용자가 직접 등록한 API 키를 통해 외부 AI 서비스(Cerebras)로 전송됩니다. 이 전송은 사용자가 질문을 보낼 때만 발생하며, 앱 개발자는 해당 내용을 수집·열람하지 않습니다. API 키는 기기 내부에만 저장됩니다.',
    ),
    (
      '3. 정보의 보관 및 파기',
      '모든 학습 데이터는 기기 내 로컬 저장소(Hive/SharedPreferences)에 보관되며, 앱 삭제 시 함께 삭제됩니다. 별도 서버 백업은 이루어지지 않습니다.',
    ),
    (
      '4. 제3자 제공',
      '앱은 사용자 정보를 제3자에게 판매하거나 제공하지 않습니다. AI 튜터 질문 텍스트의 외부 전송은 위 2항의 범위로 한정됩니다.',
    ),
    ('5. 아동의 개인정보', '앱은 아동을 대상으로 개인정보를 수집하지 않으며, 모든 연령이 안전하게 사용할 수 있습니다.'),
    (
      '6. 이용자의 권리',
      '이용자는 설정 > 데이터 초기화를 통해 언제든지 모든 로컬 데이터를 삭제할 수 있습니다. 개인정보 관련 문의는 하단 이메일로 연락해 주세요.',
    ),
  ];

  // ── 이용약관 ─────────────────────────────────────────
  static const List<(String, String)> _terms = [
    (
      '1. 서비스 개요',
      '본 앱은 전기기사·전기공사기사·소방설비기사(전기) 자격증 학습을 돕는 도구입니다. 기출문제, 이론 요약, 암기법, AI 튜터, 학습 통계 기능을 제공합니다.',
    ),
    (
      '2. 콘텐츠의 성격과 한계',
      '앱에 수록된 이론 요약·해설·암기법은 학습 보조 목적으로 재구성된 자료입니다. 실제 시험의 출제 기준·법령 개정에 따라 내용이 달라질 수 있으므로, 최종 확인은 한국산업인력공단(큐넷) 공고 및 공식 교재를 기준으로 해야 합니다.',
    ),
    (
      '3. 합격 예측·통계의 한계',
      '합격 예측, D-Day 플랜 등 통계 기능은 사용자의 학습 기록을 기반으로 한 추정치이며, 실제 시험 결과를 보장하지 않습니다.',
    ),
    (
      '4. 지식재산권',
      '앱의 UI, 구성, 재구성된 학습 콘텐츠에 대한 권리는 개발자에게 있습니다. 기출문제의 원저작권은 한국산업인력공단에 있으며, 본 앱은 학습 목적의 재구성 자료를 제공합니다.',
    ),
    (
      '5. 면책',
      '개발자는 앱 사용으로 인한 학습 결과, 시험 결과에 대해 법적 책임을 지지 않습니다. 앱은 "있는 그대로" 제공됩니다.',
    ),
  ];

  // ── AI 고지 ──────────────────────────────────────────
  static const List<(String, String)> _aiNotice = [
    (
      'AI 생성 콘텐츠 안내',
      'AI 튜터의 답변은 인공지능(대규모 언어 모델)이 생성한 것으로, 부정확하거나 최신 법령·기준과 다를 수 있습니다. 중요한 내용은 반드시 공식 교재와 큐넷 공고로 확인하세요.',
    ),
    (
      'API 키 (BYOK)',
      'AI 튜터는 사용자가 직접 발급받은 Cerebras API 키를 사용하는 BYOK(Bring Your Own Key) 방식입니다. 키는 기기에만 저장되며, 사용량·요금은 해당 서비스의 정책을 따릅니다.',
    ),
    (
      '데이터 전송',
      'AI 튜터에 입력한 텍스트는 답변 생성을 위해 외부 AI 서버로 전송됩니다. 개인정보(이름, 연락처 등)를 질문에 포함하지 않는 것을 권장합니다.',
    ),
  ];
}
