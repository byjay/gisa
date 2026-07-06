import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

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
      appBar: AppBar(title: const Text('시험 D-Day 관리')),
      body: app.exams.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('등록된 시험이 없습니다.\n+ 버튼으로 시험을 추가하세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: app.exams.length,
              itemBuilder: (context, i) {
                final exam = app.exams[i];
                final d = exam.dDay;
                final dText = d == 0 ? 'D-Day' : (d > 0 ? 'D-$d' : 'D+${-d}');
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: exam.color,
                      child: Text(
                        exam.name.isNotEmpty ? exam.name[0] : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(exam.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${DateFormat('yyyy.MM.dd').format(exam.examDate)}'
                        '${exam.category.isNotEmpty ? ' · ${exam.category}' : ''}'
                        '\n총 학습 ${_fmtMin(app.minutesForExam(exam.id))}'),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: d >= 0 && d <= 7
                                ? Colors.red.withValues(alpha: 0.1)
                                : exam.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(dText,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: d >= 0 && d <= 7
                                    ? Colors.red
                                    : exam.color,
                              )),
                        ),
                      ],
                    ),
                    onTap: () => _showExamDialog(context, exam: exam),
                    onLongPress: () => _confirmDelete(context, exam),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showExamDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _fmtMin(int m) => m >= 60 ? '${m ~/ 60}시간 ${m % 60}분' : '$m분';

  void _confirmDelete(BuildContext context, Exam exam) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('시험 삭제'),
        content: Text('"${exam.name}" 시험과 관련 기록을 모두 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              context.read<AppProvider>().deleteExam(exam.id);
              Navigator.pop(ctx);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showExamDialog(BuildContext context, {Exam? exam}) {
    final nameCtrl = TextEditingController(text: exam?.name ?? '');
    final catCtrl = TextEditingController(text: exam?.category ?? '');
    final memoCtrl = TextEditingController(text: exam?.memo ?? '');
    DateTime date = exam?.examDate ?? DateTime.now().add(const Duration(days: 30));
    int colorValue = exam?.colorValue ?? _colors[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(exam == null ? '시험 추가' : '시험 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '시험 이름 *'),
                ),
                TextField(
                  controller: catCtrl,
                  decoration: const InputDecoration(labelText: '분야 (예: IT, 어학)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('시험일: '),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setState(() => date = picked);
                      },
                      child: Text(DateFormat('yyyy.MM.dd').format(date)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: _colors
                      .map((c) => GestureDetector(
                            onTap: () => setState(() => colorValue = c),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(c),
                              child: colorValue == c
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : null,
                            ),
                          ))
                      .toList(),
                ),
                TextField(
                  controller: memoCtrl,
                  decoration: const InputDecoration(labelText: '메모'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final app = context.read<AppProvider>();
                if (exam == null) {
                  app.addExam(Exam(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text.trim(),
                    category: catCtrl.text.trim(),
                    examDate: date,
                    memo: memoCtrl.text.trim(),
                    colorValue: colorValue,
                  ));
                } else {
                  exam
                    ..name = nameCtrl.text.trim()
                    ..category = catCtrl.text.trim()
                    ..examDate = date
                    ..memo = memoCtrl.text.trim()
                    ..colorValue = colorValue;
                  app.updateExam(exam);
                }
                Navigator.pop(ctx);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}
