import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../services/qnet_catalog.dart';
import '../services/qnet_schedule_service.dart';
import '../services/schedule_alerts.dart';
import '../services/exam_registration.dart';
import '../services/cbt_info_service.dart';
import '../services/exam_analysis.dart';
import '../services/pass_prediction.dart';

/// 📅 시험 일정 화면 — Q-Net 실시간 연동판.
///
/// 구성:
///  1) 종목 선택(칩) + 새로고침
///  2) 임박 알림(원서접수/시험/합격발표)
///  3) 회차별 시험일정 카드 (응시 선택 + 가답안 채점)
///  4) CBT 정보 / 가답안 게시판 진입
class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  CbtInfo? _cbt;
  bool _loadingCbt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCbt());
  }

  Future<void> _loadCbt() async {
    final app = context.read<AppProvider>();
    final item = app.catalogItem;
    if (!item.isQnet || item.jmCd == null) {
      setState(() => _cbt = null);
      return;
    }
    setState(() => _loadingCbt = true);
    final info = await CbtInfoService.instance.fetch(item.jmCd!, item.name,
        seriesCd: item.seriesCd, catalogId: item.id);
    if (mounted) {
      setState(() {
        _cbt = info;
        _loadingCbt = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('시험 일정'),
        actions: [
          IconButton(
            tooltip: '큐넷 원문 열기',
            onPressed: () => _openQnetDetail(app.catalogItem),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
          IconButton(
            tooltip: '새로고침',
            onPressed: () async {
              await app.refreshSchedule(force: true);
              CbtInfoService.instance.clearCache();
              _loadCbt();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await app.refreshSchedule(force: true);
          CbtInfoService.instance.clearCache();
          await _loadCbt();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
          children: [
            _CatalogPicker(
              selectedId: app.catalogId,
              onSelect: (id) {
                app.selectCatalog(id);
                _loadCbt();
              },
            ),
            const SizedBox(height: 14),
            _StatusBanner(app: app),
            if (app.alerts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionTitle('🔔 다가오는 알림', count: app.alerts.length),
              const SizedBox(height: 8),
              ...app.alerts.take(6).map((a) => _AlertTile(alert: a)),
            ],
            const SizedBox(height: 18),
            _CbtCard(
              info: _cbt,
              loading: _loadingCbt,
              onTrial: () => _launch(CbtInfo.cbtTrialUrl),
              onAnswerBoard: () => _launch(CbtInfo.answerBoardUrl),
            ),
            const SizedBox(height: 18),
            _SectionTitle('🗓 회차별 시험일정',
                count: app.qnetRounds.isEmpty ? null : app.qnetRounds.length),
            const SizedBox(height: 4),
            Text(
              app.scheduleFetchedAt != null
                  ? '실시간 연동 · ${DateFormat('M월 d일 HH:mm').format(app.scheduleFetchedAt!)} 기준'
                  : '큐넷에서 실시간으로 불러옵니다.',
              style: TextStyle(
                fontSize: 11.5,
                color: _muted(context),
              ),
            ),
            const SizedBox(height: 10),
            if (app.loadingSchedule && app.qnetRounds.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (app.qnetRounds.isEmpty)
              _EmptySchedule(
                message: app.scheduleError ?? '표시할 일정이 없어요.',
                onRetry: () => app.refreshSchedule(force: true),
              )
            else
              ...app.qnetRounds.map(
                (r) => _RoundCard(
                  round: r,
                  item: app.catalogItem,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white54
          : AppTheme.textMuted;

  Future<void> _openQnetDetail(CatalogItem item) async {
    final jm = item.jmCd ?? '1150';
    final uri =
        Uri.parse('https://www.q-net.or.kr/crf005.do?id=crf00503&jmCd=$jm');
    await _launch(uri.toString());
  }

  Future<void> _launch(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

// ══════════════════════════════════════════════════════════════
// 종목 선택 칩
// ══════════════════════════════════════════════════════════════
class _CatalogPicker extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _CatalogPicker({required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('📚 연동할 종목'),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kQnetCatalog.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final item = kQnetCatalog[i];
              final sel = item.id == selectedId;
              return ChoiceChip(
                selected: sel,
                onSelected: (_) => onSelect(item.id),
                avatar: Text(item.emoji,
                    style: const TextStyle(fontSize: 14)),
                label: Text(item.name),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: sel
                      ? Colors.white
                      : (dark ? Colors.white70 : AppTheme.textBody),
                ),
                selectedColor: AppTheme.primary,
                backgroundColor:
                    dark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF3F4F6),
                showCheckmark: false,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 상단 상태 배너 (가장 임박한 알림 or 로딩/에러)
// ══════════════════════════════════════════════════════════════
class _StatusBanner extends StatelessWidget {
  final AppProvider app;
  const _StatusBanner({required this.app});

  @override
  Widget build(BuildContext context) {
    final top = app.topAlert;
    if (top != null) {
      return PremiumCard(
        gradient: AppTheme.heroGradient,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(top.type.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${top.type.label} ${top.dDayLabel}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    top.message,
                    style: const TextStyle(
                      color: Color(0xFFE3E8FF),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const IconBadge(
              icon: Icons.notifications_active_rounded,
              color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              app.loadingSchedule
                  ? '실시간 시험일정을 불러오는 중…'
                  : '지금은 임박한 일정 알림이 없어요. 회차 일정을 확인해 보세요.',
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 알림 타일
// ══════════════════════════════════════════════════════════════
class _AlertTile extends StatelessWidget {
  final ScheduleAlert alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = switch (alert.type) {
      AlertType.regOpen => const Color(0xFF0891B2),
      AlertType.examSoon => AppTheme.danger,
      AlertType.resultSoon => const Color(0xFF16A34A),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PremiumCard(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Text(alert.type.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${alert.phaseLabel} ${alert.type.label}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert.message,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white60
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PillBadge(
              text: alert.dDayLabel,
              color: color,
              filled: alert.ongoing || alert.dDay <= 3,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CBT 정보 카드
// ══════════════════════════════════════════════════════════════
class _CbtCard extends StatelessWidget {
  final CbtInfo? info;
  final bool loading;
  final VoidCallback onTrial;
  final VoidCallback onAnswerBoard;

  const _CbtCard({
    required this.info,
    required this.loading,
    required this.onTrial,
    required this.onAnswerBoard,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.white54
        : AppTheme.textMuted;
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                  icon: Icons.computer_rounded, color: Color(0xFF7C3AED)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('CBT 시험 정보 (실시간)',
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800)),
              ),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (info != null)
                PillBadge(
                  text: info!.cbtEnabled ? 'CBT 시행' : 'CBT 미시행',
                  color: info!.cbtEnabled
                      ? const Color(0xFF16A34A)
                      : AppTheme.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (info != null) ...[
            Row(
              children: [
                Expanded(
                    child: _feeBox('필기 수수료', info!.feeWritten, muted)),
                const SizedBox(width: 10),
                Expanded(
                    child: _feeBox('실기 수수료', info!.feePractical, muted)),
              ],
            ),
            if (info!.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...info!.notes.take(3).map(
                    (n) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ',
                              style: TextStyle(color: muted, fontSize: 12)),
                          Expanded(
                            child: Text(n,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.35,
                                    color: muted)),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ] else if (!loading)
            Text('CBT 정보를 불러오지 못했어요.',
                style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTrial,
                  icon: const Icon(Icons.play_circle_outline_rounded,
                      size: 18),
                  label: const Text('CBT 체험'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAnswerBoard,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('가답안 게시판'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feeBox(String label, String value, Color muted) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 회차 카드 (응시 선택 + 가답안)
// ══════════════════════════════════════════════════════════════
class _RoundCard extends StatelessWidget {
  final QnetExamRound round;
  final CatalogItem item;

  const _RoundCard({required this.round, required this.item});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.white54
        : AppTheme.textMuted;

    final writtenReg = app.registrationFor(
        item.jmCd ?? '', round.label, ExamPhase.written);
    final practicalReg = app.registrationFor(
        item.jmCd ?? '', round.label, ExamPhase.practical);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(item.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    round.label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                if (round.anchorDate != null)
                  PillBadge(
                    text: _ddayLabel(round.anchorDate!),
                    color: AppTheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _phaseBlock(
              context,
              title: '필기',
              color: const Color(0xFF4F46E5),
              reg: round.writtenReg,
              exam: round.writtenExam,
              result: round.writtenResult,
              muted: muted,
              registration: writtenReg,
              phase: ExamPhase.written,
              app: app,
            ),
            const Divider(height: 24),
            _phaseBlock(
              context,
              title: '실기',
              color: const Color(0xFF0891B2),
              reg: round.practicalReg,
              exam: round.practicalExam,
              result: round.finalResult,
              muted: muted,
              registration: practicalReg,
              phase: ExamPhase.practical,
              app: app,
            ),
          ],
        ),
      ),
    );
  }

  Widget _phaseBlock(
    BuildContext context, {
    required String title,
    required Color color,
    required DateRange? reg,
    required DateRange? exam,
    required DateTime? result,
    required Color muted,
    required ExamRegistration? registration,
    required ExamPhase phase,
    required AppProvider app,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PillBadge(text: title, color: color, filled: true),
            const Spacer(),
            if (registration != null)
              PillBadge(text: registration.status.label, color: color),
          ],
        ),
        const SizedBox(height: 8),
        _dateRow(Icons.edit_calendar_outlined, '원서접수',
            _rangeText(reg), muted),
        _dateRow(Icons.assignment_outlined, '시험일',
            _rangeText(exam), muted),
        _dateRow(Icons.emoji_events_outlined, '합격발표',
            result != null ? _dateText(result) : '-', muted),
        if (registration?.score != null) ...[
          const SizedBox(height: 8),
          _scoreSummary(registration!, muted),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    _openStatusSheet(context, app, phase, registration),
                icon: const Icon(Icons.how_to_reg_outlined, size: 17),
                label: Text(registration == null ? '응시 선택' : '상태 변경'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () =>
                    _openScoreSheet(context, app, phase, registration),
                icon: const Icon(Icons.calculate_outlined, size: 17),
                label: const Text('가답안 채점'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 학습정보·과거정보 연동 분석 진입
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () =>
                _openAnalysisSheet(context, phase, registration),
            icon: const Icon(Icons.insights_rounded, size: 18),
            label: const Text('합격 분석 (내 학습데이터 연동)'),
          ),
        ),
      ],
    );
  }

  /// 통합 분석 시트: 크롤링 시험일(D-Day) + 과거 학습데이터 예측 + 플랜 + 가답안 비교.
  void _openAnalysisSheet(
      BuildContext context, ExamPhase phase, ExamRegistration? reg) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, sc) => FutureBuilder<ExamAnalysis>(
          future: ExamAnalysisEngine.instance.analyze(
            round: round,
            phase: phase,
            registration: reg,
          ),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return _AnalysisReport(
                analysis: snap.data!, item: item, scroll: sc);
          },
        ),
      ),
    );
  }

  Widget _scoreSummary(ExamRegistration reg, Color muted) {
    final pass = reg.likelyPass;
    final color = pass == null
        ? muted
        : (pass ? const Color(0xFF16A34A) : AppTheme.danger);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            pass == true
                ? Icons.check_circle_rounded
                : (pass == false
                    ? Icons.cancel_rounded
                    : Icons.help_outline_rounded),
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '가답안 ${reg.score!.toStringAsFixed(1)}점 '
              '(${reg.scoredCorrect}/${reg.scoredTotal})'
              '${(reg.subjectFails ?? 0) > 0 ? ' · 과락 ${reg.subjectFails}과목' : ''}',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          Text(
            pass == null ? '' : (pass ? '합격 예상' : '불합격 예상'),
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _dateRow(IconData icon, String label, String value, Color muted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 15, color: muted),
          const SizedBox(width: 7),
          SizedBox(
            width: 62,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // 응시 상태 선택 시트
  void _openStatusSheet(BuildContext context, AppProvider app,
      ExamPhase phase, ExamRegistration? existing) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${round.label} · ${phase.label} 응시 상태',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (existing != null)
                    TextButton(
                      onPressed: () {
                        app.deleteRegistration(existing.id);
                        Navigator.pop(ctx);
                      },
                      child: const Text('해제',
                          style: TextStyle(color: AppTheme.danger)),
                    ),
                ],
              ),
            ),
            ...RegStatus.values.map(
              (s) => ListTile(
                leading: Icon(_statusIcon(s), color: AppTheme.primary),
                title: Text(s.label),
                trailing: existing?.status == s
                    ? const Icon(Icons.check_rounded,
                        color: AppTheme.primary)
                    : null,
                onTap: () {
                  _setStatus(app, phase, existing, s);
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _setStatus(AppProvider app, ExamPhase phase,
      ExamRegistration? existing, RegStatus status) {
    final id =
        ExamRegistration.makeId(item.jmCd ?? '', round.label, phase);
    final reg = existing ??
        ExamRegistration(
          id: id,
          jmCd: item.jmCd ?? '',
          catalogId: item.id,
          certName: item.name,
          roundLabel: round.label,
          phase: phase,
        );
    reg.status = status;
    app.saveRegistration(reg);
  }

  // 가답안 채점 시트
  void _openScoreSheet(BuildContext context, AppProvider app,
      ExamPhase phase, ExamRegistration? existing) {
    final subjects =
        phase == ExamPhase.written ? item.subjects.length : 1;
    final totalCtrl = TextEditingController(
        text: (existing?.scoredTotal ??
                (phase == ExamPhase.written ? subjects * 20 : 100))
            .toString());
    final correctCtrl = TextEditingController(
        text: existing?.scoredCorrect?.toString() ?? '');
    final failCtrl = TextEditingController(
        text: (existing?.subjectFails ?? 0).toString());

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${round.label} · ${phase.label} 가답안 채점',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '발표된 가답안과 내 답을 대조해 맞힌 문항 수를 입력하면 예상 점수를 계산해요.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.white54
                          : AppTheme.textMuted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: totalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '총 문항 수',
                    prefixIcon: Icon(Icons.format_list_numbered_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: correctCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '맞힌 문항 수',
                    prefixIcon: Icon(Icons.check_circle_outline_rounded),
                  ),
                ),
                if (phase == ExamPhase.written) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: failCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '과락 과목 수 (40점 미만 과목)',
                      prefixIcon: Icon(Icons.warning_amber_rounded),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final total = int.tryParse(totalCtrl.text.trim());
                      final correct =
                          int.tryParse(correctCtrl.text.trim());
                      if (total == null ||
                          correct == null ||
                          total <= 0 ||
                          correct < 0 ||
                          correct > total) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('문항 수를 올바르게 입력해 주세요.')),
                        );
                        return;
                      }
                      _saveScore(app, phase, existing, total, correct,
                          int.tryParse(failCtrl.text.trim()) ?? 0);
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.calculate_rounded),
                    label: const Text('점수 계산 & 저장'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveScore(AppProvider app, ExamPhase phase,
      ExamRegistration? existing, int total, int correct, int fails) {
    final id =
        ExamRegistration.makeId(item.jmCd ?? '', round.label, phase);
    final reg = existing ??
        ExamRegistration(
          id: id,
          jmCd: item.jmCd ?? '',
          catalogId: item.id,
          certName: item.name,
          roundLabel: round.label,
          phase: phase,
          status: RegStatus.taken,
        );
    reg.scoredTotal = total;
    reg.scoredCorrect = correct;
    reg.subjectFails = phase == ExamPhase.written ? fails : 0;
    reg.scoredAt = DateTime.now();
    if (reg.status == RegStatus.planned ||
        reg.status == RegStatus.registered) {
      reg.status = RegStatus.taken;
    }
    app.saveRegistration(reg);
    // 학습이력(퀴즈결과)에도 가답안 기록을 연동해 통계·XP 분석에 반영
    app.addQuizResult(
      title: '${item.name} ${round.label} ${phase.label} 가답안',
      total: total,
      correct: correct,
    );
    // 과거 점수 이력(ScoreHistory)에 "실제 시험 결과" 스냅샷으로 연동
    // → 통계·추세 그래프가 예측뿐 아니라 실측까지 함께 담게 된다.
    ExamAnalysisEngine.instance.recordActualToHistory(reg);
  }

  IconData _statusIcon(RegStatus s) {
    switch (s) {
      case RegStatus.planned:
        return Icons.flag_outlined;
      case RegStatus.registered:
        return Icons.assignment_turned_in_outlined;
      case RegStatus.taken:
        return Icons.done_all_rounded;
      case RegStatus.passed:
        return Icons.emoji_events_rounded;
      case RegStatus.failed:
        return Icons.replay_rounded;
    }
  }

  String _rangeText(DateRange? r) {
    if (r == null) return '-';
    if (r.isSingleDay) return _dateText(r.start);
    return '${_dateText(r.start)} ~ ${_dateText(r.end)}';
  }

  String _dateText(DateTime d) => DateFormat('yyyy.MM.dd').format(d);

  String _ddayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final t = DateTime(d.year, d.month, d.day);
    final diff = t.difference(today).inDays;
    if (diff == 0) return 'D-DAY';
    if (diff > 0) return 'D-$diff';
    return '종료';
  }
}

// ══════════════════════════════════════════════════════════════
// 공용 위젯
// ══════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String text;
  final int? count;
  const _SectionTitle(this.text, {this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 15.5, fontWeight: FontWeight.w800)),
        if (count != null) ...[
          const SizedBox(width: 6),
          PillBadge(text: '$count', color: AppTheme.primary),
        ],
      ],
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _EmptySchedule({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 50, color: AppTheme.textMuted.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 통합 분석 리포트 (학습정보·과거정보 연동)
// ══════════════════════════════════════════════════════════════
class _AnalysisReport extends StatelessWidget {
  final ExamAnalysis analysis;
  final CatalogItem item;
  final ScrollController scroll;

  const _AnalysisReport({
    required this.analysis,
    required this.item,
    required this.scroll,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? Colors.white54 : AppTheme.textMuted;
    final p = analysis.prediction;
    final plan = analysis.plan;

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: dark ? Colors.white24 : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text('${item.name} · ${analysis.roundLabel}',
            style: TextStyle(fontSize: 12.5, color: muted)),
        const SizedBox(height: 2),
        Text('${analysis.phase.label} 합격 분석',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),

        // 예측 점수 + D-Day 헤더
        PremiumCard(
          gradient: AppTheme.heroGradient,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('과거 학습데이터 기반 예측',
                        style: TextStyle(
                            color: Color(0xFFDDE5FF), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('${p.overall.toStringAsFixed(0)}점',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900)),
                    Text(
                      p.needsDiagnosis
                          ? '데이터 부족 · 진단 필요'
                          : (p.pass ? '합격권 예측 ✅' : '합격선 미달'),
                      style: const TextStyle(
                          color: Color(0xFFDDE5FF), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  const Icon(Icons.event_rounded,
                      color: Colors.white70, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    analysis.dDay == null
                        ? '-'
                        : (analysis.dDay! >= 0
                            ? 'D-${analysis.dDay}'
                            : '종료'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900),
                  ),
                  const Text('시험일',
                      style: TextStyle(
                          color: Color(0xFFDDE5FF), fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 코칭 문구
        PremiumCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Text('🧭', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(analysis.coaching,
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 가답안 실측 vs 예측 비교 (있을 때만)
        if (analysis.actualScore != null) ...[
          _SectionTitle('📊 가답안 실측 vs 예측'),
          const SizedBox(height: 8),
          PremiumCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _compareCol('예측', p.overall, muted),
                _arrow(analysis.predVsActualGap ?? 0),
                _compareCol('실측(가답안)', analysis.actualScore!, muted,
                    strong: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // D-Day 학습 플랜 (있을 때만)
        if (plan != null && analysis.dDay != null && analysis.dDay! >= 0) ...[
          _SectionTitle('🗓 D-Day 합격 플랜'),
          const SizedBox(height: 8),
          PremiumCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _planRow('목표 점수', '${plan.targetScore.toStringAsFixed(0)}점',
                    muted),
                _planRow('남은 점수',
                    '${plan.pointsNeeded.toStringAsFixed(0)}점', muted),
                _planRow('필요 문제 수', '${plan.questionsNeeded}문제', muted),
                _planRow('하루 권장량', '${plan.perDay}문제', muted,
                    highlight: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 과목별 예측 + 과락 경보
        _SectionTitle('📚 과목별 예측'),
        const SizedBox(height: 8),
        ...p.subjects.map((s) => _subjectBar(s, muted)),

        // 처방전
        if (p.prescriptions.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionTitle('💊 오늘의 처방 (점수 올릴 약점)'),
          const SizedBox(height: 8),
          ...p.prescriptions.map(
            (rx) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PremiumCard(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    const IconBadge(
                        icon: Icons.local_hospital_rounded,
                        color: Color(0xFF16A34A),
                        size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${rx.subject} · ${rx.topic}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                          Text('기출 ${rx.topicQuestionCount}문항',
                              style: TextStyle(fontSize: 11, color: muted)),
                        ],
                      ),
                    ),
                    PillBadge(
                        text: '+${rx.expectedGain.toStringAsFixed(1)}점',
                        color: const Color(0xFF16A34A)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _compareCol(String label, double v, Color muted,
      {bool strong = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: muted)),
          const SizedBox(height: 4),
          Text('${v.toStringAsFixed(0)}점',
              style: TextStyle(
                  fontSize: strong ? 24 : 20,
                  fontWeight: FontWeight.w900,
                  color: strong ? AppTheme.primary : null)),
        ],
      ),
    );
  }

  Widget _arrow(double gap) {
    final up = gap >= 0;
    return Column(
      children: [
        Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: up ? const Color(0xFF16A34A) : AppTheme.danger),
        Text('${up ? '+' : ''}${gap.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: up ? const Color(0xFF16A34A) : AppTheme.danger)),
      ],
    );
  }

  Widget _planRow(String label, String value, Color muted,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: muted)),
          Text(value,
              style: TextStyle(
                  fontSize: highlight ? 16 : 13.5,
                  fontWeight: FontWeight.w800,
                  color: highlight ? AppTheme.primary : null)),
        ],
      ),
    );
  }

  Widget _subjectBar(SubjectPrediction s, Color muted) {
    final ratio = (s.score / 100).clamp(0.0, 1.0);
    final color = s.gwarak
        ? AppTheme.danger
        : (s.score >= 60 ? const Color(0xFF16A34A) : const Color(0xFFF59E0B));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              if (s.gwarak)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: PillBadge(text: '과락위험', color: AppTheme.danger),
                ),
              Text('${s.score.toStringAsFixed(0)}점',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
