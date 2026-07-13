import 'package:flutter/material.dart';
import '../../services/study_data.dart';
import '../../theme/app_theme.dart';

/// 합격 공부법 — 딥리서치(합격후기·기출현황) 기반 학습 전략 가이드
class StudyGuideScreen extends StatefulWidget {
  const StudyGuideScreen({super.key});

  @override
  State<StudyGuideScreen> createState() => _StudyGuideScreenState();
}

class _StudyGuideScreenState extends State<StudyGuideScreen> {
  StudyGuide? _guide;
  bool _loading = true;
  bool _majorTab = false; // false=비전공자, true=전공자

  @override
  void initState() {
    super.initState();
    StudyData.instance.loadStudyGuide().then((g) {
      if (mounted) {
        setState(() {
          _guide = g;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = _guide;
    return Scaffold(
      appBar: AppBar(
        title: const Text('합격 공부법'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : g == null
              ? const Center(child: Text('공부법 데이터를 불러오지 못했습니다.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _header(g),
                    const SizedBox(height: 16),
                    if (g.examNote != null) _examNote(g.examNote!),
                    if (g.order != null) _orderCard(g.order!),
                    if (g.subjects.isNotEmpty) _subjectsSection(g.subjects),
                    if (g.principles != null) _principles(g.principles!),
                    if (g.period != null) _period(g.period!),
                  ],
                ),
    );
  }

  // ── 헤더 ──────────────────────────────────────────────
  Widget _header(StudyGuide g) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.rLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: Colors.amber, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  g.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            g.intro,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  // ── 섹션 타이틀 공통 ──────────────────────────────────
  Widget _sectionTitle(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, Color? bg, Color? border}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        border: border != null ? Border.all(color: border, width: 1.2) : null,
        boxShadow: bg == null
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  // ── 기출 데이터 신뢰도 안내 ───────────────────────────
  Widget _examNote(GuideNote n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.verified_rounded, n.title, AppTheme.success),
        _card(
          bg: AppTheme.success.withValues(alpha: 0.08),
          border: AppTheme.success.withValues(alpha: 0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                n.body,
                style: const TextStyle(fontSize: 13, height: 1.7),
              ),
              if (n.highlights.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final h in n.highlights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.success, size: 17),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            h,
                            style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.5,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── 과목 공부 순서 (전공/비전공 토글) ─────────────────
  Widget _orderCard(GuideOrder o) {
    final path = _majorTab ? o.major : o.nonMajor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.route_rounded, o.title, AppTheme.primary),
        if (o.body.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(o.body,
                style: const TextStyle(fontSize: 13, height: 1.6)),
          ),
        // 토글
        Row(
          children: [
            _toggle('비전공자', !_majorTab, () => setState(() => _majorTab = false)),
            const SizedBox(width: 8),
            _toggle('전공자', _majorTab, () => setState(() => _majorTab = true)),
          ],
        ),
        const SizedBox(height: 12),
        if (path != null)
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(path.label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(path.reason,
                    style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.55,
                        color: AppTheme.textMuted)),
                const SizedBox(height: 14),
                for (var i = 0; i < path.steps.length; i++) ...[
                  _stepRow(i + 1, path.steps[i],
                      isLast: i == path.steps.length - 1),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _toggle(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.rSm),
            border: Border.all(
              color: active
                  ? AppTheme.primary
                  : AppTheme.textMuted.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepRow(int n, String text, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text('$n',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: EdgeInsets.only(top: 3, bottom: isLast ? 0 : 14),
            child: Text(text,
                style:
                    const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── 과목별 공부법 ─────────────────────────────────────
  Widget _subjectsSection(List<GuideSubject> subjects) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.menu_book_rounded, '과목별 공부법', AppTheme.accent),
        for (final s in subjects)
          _card(
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 4),
                title: Text(s.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    s.role,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(s.method,
                        style: const TextStyle(fontSize: 13, height: 1.65)),
                  ),
                  if (s.tips.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in s.tips)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── 합격자 공통 원칙 ──────────────────────────────────
  Widget _principles(GuideList p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.tips_and_updates_rounded, p.title, AppTheme.warning),
        _card(
          bg: AppTheme.warning.withValues(alpha: 0.07),
          border: AppTheme.warning.withValues(alpha: 0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < p.items.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                      bottom: i == p.items.length - 1 ? 0 : 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.warning)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p.items[i],
                            style:
                                const TextStyle(fontSize: 13, height: 1.6)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 권장 학습 기간 ────────────────────────────────────
  Widget _period(GuidePeriod p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.schedule_rounded, p.title, AppTheme.electric),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(p.body,
                      style: const TextStyle(fontSize: 13, height: 1.65)),
                ),
              for (final row in p.table)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(row.isNotEmpty ? row[0] : '',
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(row.length > 1 ? row[1] : '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textMuted)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(row.length > 2 ? row[2] : '',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.electric)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
