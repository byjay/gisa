import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/exam_track.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  String? _trackId;

  ExamTrack get _track => trackById(
    _trackId ??
        context.read<AppProvider>().selectedTrackId ??
        kExamTracks.first.id,
  );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final track = _track;
    final activeCount = app.activeSubjectsFor(track).length;

    return Scaffold(
      appBar: AppBar(title: const Text('관리자 설정')),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 800
              ? (MediaQuery.of(context).size.width - 680) / 2
              : 14,
          vertical: 14,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '운영 정책',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '이 설정은 현재 기기의 사용자 초기값으로 저장됩니다. 최소 한 과목은 항상 활성 상태로 유지됩니다.',
                    style: TextStyle(fontSize: 12.5, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _title(context, '기능 노출'),
          Card(
            child: Column(
              children: [
                _featureSwitch(app, 'theory', '이론 학습', Icons.menu_book_rounded),
                const Divider(height: 1),
                _featureSwitch(app, 'practice', '문제 풀이', Icons.quiz_rounded),
                const Divider(height: 1),
                _featureSwitch(app, 'cbt', 'CBT·모의고사', Icons.computer_rounded),
                const Divider(height: 1),
                _featureSwitch(app, 'flashcards', '암기 카드', Icons.style_rounded),
                const Divider(height: 1),
                _featureSwitch(
                  app,
                  'aiTutor',
                  'AI 튜터',
                  Icons.smart_toy_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _title(context, '시험 설정'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.timer_rounded),
                  title: const Text('시험 진입 시 자동 타이머'),
                  subtitle: const Text('CBT와 실전 모의고사에서 즉시 시작'),
                  value: app.autoExamTimerEnabled,
                  onChanged: app.setAutoExamTimerEnabled,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('CBT 제한 시간'),
                  subtitle: Text('${app.cbtTimeLimitMinutes}분'),
                  trailing: DropdownButton<int>(
                    value: app.cbtTimeLimitMinutes,
                    items: const [60, 90, 120, 150, 180, 240, 300]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value분'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) app.setCbtTimeLimitMinutes(value);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.format_list_numbered_rounded),
                  title: const Text('랜덤 CBT 과목당 문항 수'),
                  subtitle: Text(
                    '$activeCount과목 × ${app.cbtQuestionsPerSubject}문항 = 최대 ${activeCount * app.cbtQuestionsPerSubject}문항',
                  ),
                  trailing: DropdownButton<int>(
                    value: app.cbtQuestionsPerSubject,
                    items: const [5, 10, 15, 20, 25, 30, 40]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) app.setCbtQuestionsPerSubject(value);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _title(context, '종목별 과목 노출'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: DropdownButtonFormField<String>(
                initialValue: track.id,
                decoration: const InputDecoration(
                  labelText: '설정할 자격 종목',
                  border: OutlineInputBorder(),
                ),
                items: kExamTracks
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _trackId = value),
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < track.subjects.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  SwitchListTile(
                    secondary: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(track.subjects[i]),
                    subtitle: Text(
                      app.isSubjectEnabled(track.id, track.subjects[i])
                          ? '홈·문제풀이·CBT에 노출'
                          : '학습 콘텐츠에서 숨김',
                    ),
                    value: app.isSubjectEnabled(track.id, track.subjects[i]),
                    onChanged: (value) async {
                      final changed = await app.setSubjectEnabled(
                        track,
                        track.subjects[i],
                        value,
                      );
                      if (!changed && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('최소 한 과목은 활성화해야 합니다.')),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _confirmReset(context, app),
            icon: const Icon(Icons.restore_rounded),
            label: const Text('관리자 설정 기본값 복원'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _featureSwitch(
    AppProvider app,
    String key,
    String title,
    IconData icon,
  ) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      value: app.isFeatureEnabled(key),
      onChanged: (value) => app.setFeatureEnabled(key, value),
    );
  }

  Widget _title(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    ),
  );

  Future<void> _confirmReset(BuildContext context, AppProvider app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('기본값으로 복원할까요?'),
        content: const Text('모든 기능과 과목이 다시 활성화되고 시험 설정이 초기화됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('복원'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await app.resetAdminSettings();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('관리자 설정을 기본값으로 복원했습니다.')));
      }
    }
  }
}
