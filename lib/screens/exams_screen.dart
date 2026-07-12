import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class ExamsScreen extends StatelessWidget {
  const ExamsScreen({super.key});

  static const _colors = [
    0xFF5C6BC0,
    0xFFEF5350,
    0xFF66BB6A,
    0xFFFFA726,
    0xFFAB47BC,
    0xFF26A69A,
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('시험 일정'),
        actions: [
          IconButton(
            tooltip: '큐넷에서 일정 검색',
            onPressed: _openQnet,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: _QnetBanner(onTap: () => _showExamPicker(context)),
            ),
          ),
          if (app.exams.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(onSelect: () => _showExamPicker(context)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              sliver: SliverList.separated(
                itemCount: app.exams.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final exam = app.exams[index];
                  return _ExamScheduleCard(
                    exam: exam,
                    studyMinutes: app.minutesForExam(exam.id),
                    onTap: () => _showExamPicker(context, editing: exam),
                    onDelete: () => _confirmDelete(context, exam),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExamPicker(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('시험 추가'),
      ),
    );
  }

  Future<void> _openQnet() async {
    // 전기기사 국가자격 종목별 상세정보 (회차별 원서접수 일정 + 접수 진입)
    // 검증: Q-net 공식 crf00503 · jmCd=1150(전기기사)
    final uri =
        Uri.parse('https://www.q-net.or.kr/crf005.do?id=crf00503&jmCd=1150');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _confirmDelete(BuildContext context, Exam exam) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('시험 삭제'),
        content: Text('“${exam.name}” 시험과 관련 기록을 모두 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              context.read<AppProvider>().deleteExam(exam.id);
              Navigator.pop(dialogContext);
            },
            child: const Text('삭제', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }

  void _showExamPicker(BuildContext context, {Exam? editing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ExamPickerSheet(
        editing: editing,
        colors: _colors,
        onOpenQnet: _openQnet,
      ),
    );
  }
}

class _QnetBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _QnetBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      gradient: AppTheme.heroGradient,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: const Row(
        children: [
          _QnetMark(),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '큐넷에서 시험을 찾아보세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '다가오는 시험을 선택하면 D-Day가 자동 등록됩니다.',
                  style: TextStyle(
                    color: Color(0xFFDDE5FF),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

class _QnetMark extends StatelessWidget {
  const _QnetMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Icon(Icons.search_rounded, color: Colors.white, size: 26),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onSelect;

  const _EmptyState({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.white54
        : AppTheme.textMuted;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 62,
              color: AppTheme.primary.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 18),
            const Text(
              '등록된 시험이 없어요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '큐넷 시험 일정을 검색하고\n다가오는 시험을 선택해 보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, height: 1.5),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onSelect,
              icon: const Icon(Icons.search_rounded),
              label: const Text('큐넷 시험 검색'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamScheduleCard extends StatelessWidget {
  final Exam exam;
  final int studyMinutes;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ExamScheduleCard({
    required this.exam,
    required this.studyMinutes,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final days = exam.dDay;
    final dDay = days == 0
        ? 'D-DAY'
        : days > 0
        ? 'D-$days'
        : 'D+${-days}';
    final urgent = days >= 0 && days <= 7;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.white54
        : AppTheme.textMuted;
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          IconBadge(
            icon: Icons.workspace_premium_rounded,
            color: exam.color,
            size: 48,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${DateFormat('yyyy년 M월 d일').format(exam.examDate)}${exam.category.isNotEmpty ? ' · ${exam.category}' : ''}',
                  style: TextStyle(fontSize: 12.5, color: muted),
                ),
                const SizedBox(height: 5),
                Text(
                  '누적 학습 ${_formatMinutes(studyMinutes)}',
                  style: TextStyle(fontSize: 11.5, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PillBadge(
                text: dDay,
                color: urgent ? AppTheme.danger : exam.color,
                filled: urgent,
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.more_horiz_rounded, color: muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) =>
      minutes >= 60 ? '${minutes ~/ 60}시간 ${minutes % 60}분' : '$minutes분';
}

class _QnetExam {
  final String name;
  final String category;
  final DateTime date;
  final String phase;

  const _QnetExam({
    required this.name,
    required this.category,
    required this.date,
    required this.phase,
  });
}

class _ExamPickerSheet extends StatefulWidget {
  final Exam? editing;
  final List<int> colors;
  final Future<void> Function() onOpenQnet;

  const _ExamPickerSheet({
    required this.editing,
    required this.colors,
    required this.onOpenQnet,
  });

  @override
  State<_ExamPickerSheet> createState() => _ExamPickerSheetState();
}

class _ExamPickerSheetState extends State<_ExamPickerSheet> {
  final _searchController = TextEditingController();
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _memoController;
  late DateTime _selectedDate;
  late int _colorValue;
  _QnetExam? _selectedExam;

  @override
  void initState() {
    super.initState();
    final exam = widget.editing;
    _nameController = TextEditingController(text: exam?.name ?? '');
    _categoryController = TextEditingController(text: exam?.category ?? '');
    _memoController = TextEditingController(text: exam?.memo ?? '');
    _selectedDate = exam?.examDate ?? _upcomingExams.first.date;
    _colorValue = exam?.colorValue ?? widget.colors.first;
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  List<_QnetExam> get _upcomingExams {
    final now = DateTime.now();
    DateTime nextDate(int monthOffset, int day) {
      final candidate = DateTime(now.year, now.month + monthOffset, day);
      return candidate.isAfter(now)
          ? candidate
          : DateTime(now.year, now.month + monthOffset + 1, day);
    }

    return [
      _QnetExam(
        name: '정보처리기사',
        category: '정보통신',
        date: nextDate(1, 23),
        phase: '필기시험',
      ),
      _QnetExam(
        name: '전기기사',
        category: '전기·전자',
        date: nextDate(2, 12),
        phase: '필기시험',
      ),
      _QnetExam(
        name: '산업안전기사',
        category: '안전관리',
        date: nextDate(2, 19),
        phase: '필기시험',
      ),
      _QnetExam(
        name: '건축기사',
        category: '건설',
        date: nextDate(3, 10),
        phase: '필기시험',
      ),
      _QnetExam(
        name: '컴퓨터활용능력 1급',
        category: '사무',
        date: nextDate(1, 28),
        phase: '실기시험',
      ),
      _QnetExam(
        name: '한국사능력검정시험',
        category: '한국사',
        date: nextDate(3, 17),
        phase: '정기시험',
      ),
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final query = _searchController.text.trim().toLowerCase();
    final results = _upcomingExams
        .where(
          (exam) =>
              query.isEmpty ||
              exam.name.toLowerCase().contains(query) ||
              exam.category.toLowerCase().contains(query),
        )
        .toList();

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.91,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: dark ? Colors.white24 : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '시험 일정 선택',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  _QnetSearchField(
                    controller: _searchController,
                    onQnetTap: widget.onOpenQnet,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '다가오는 시험',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : AppTheme.textStrong,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '표시 일정은 선택용 안내입니다. 최종 일정은 큐넷에서 확인하세요.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: dark ? Colors.white54 : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 9),
                  if (results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('검색 결과가 없습니다.')),
                    ),
                  ...results.map(_buildScheduleOption),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    '선택한 시험',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : AppTheme.textStrong,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '시험 이름 *',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: '분야',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('시험일'),
                    subtitle: Text(
                      DateFormat(
                        'yyyy년 M월 d일 (E)',
                        'ko_KR',
                      ).format(_selectedDate),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _pickDate,
                  ),
                  Wrap(
                    spacing: 10,
                    children: widget.colors
                        .map(
                          (value) => GestureDetector(
                            onTap: () => setState(() => _colorValue = value),
                            child: CircleAvatar(
                              radius: 15,
                              backgroundColor: Color(value),
                              child: _colorValue == value
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 17,
                                    )
                                  : null,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _memoController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '메모 (선택)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(widget.editing == null ? '시험 등록하기' : '변경사항 저장'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleOption(_QnetExam exam) {
    final isSelected = _selectedExam == exam;
    final dateText = DateFormat('M월 d일').format(exam.date);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: isSelected
            ? AppTheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() {
            _selectedExam = exam;
            _nameController.text = exam.name;
            _categoryController.text = exam.category;
            _selectedDate = exam.date;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? AppTheme.primary
                    : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white12
                          : const Color(0xFFE5E7EB)),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${exam.phase} · ${exam.category}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white54
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  dateText,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isSelected ? AppTheme.primary : AppTheme.textBody,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시험 이름을 입력하거나 일정을 선택해 주세요.')),
      );
      return;
    }
    final app = context.read<AppProvider>();
    if (widget.editing == null) {
      app.addExam(
        Exam(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          category: _categoryController.text.trim(),
          examDate: _selectedDate,
          memo: _memoController.text.trim(),
          colorValue: _colorValue,
        ),
      );
    } else {
      widget.editing!
        ..name = name
        ..category = _categoryController.text.trim()
        ..examDate = _selectedDate
        ..memo = _memoController.text.trim()
        ..colorValue = _colorValue;
      app.updateExam(widget.editing!);
    }
    Navigator.pop(context);
  }
}

class _QnetSearchField extends StatelessWidget {
  final TextEditingController controller;
  final Future<void> Function() onQnetTap;

  const _QnetSearchField({required this.controller, required this.onQnetTap});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: '자격증명으로 검색 (예: 전기기사)',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: TextButton(
          onPressed: onQnetTap,
          child: const Text('큐넷 검색'),
        ),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
