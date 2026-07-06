import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('학습 기록')),
      body: app.sessions.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_edu, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('학습 기록이 없습니다.\n타이머를 사용하거나 + 버튼으로 직접 기록하세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: app.sessions.length,
              itemBuilder: (context, i) {
                final s = app.sessions[i];
                final exam = app.examById(s.examId);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          (exam?.color ?? Colors.grey).withValues(alpha: 0.15),
                      child: Icon(Icons.menu_book,
                          color: exam?.color ?? Colors.grey),
                    ),
                    title: Text(
                        '${s.minutes}분 ${s.subject.isNotEmpty ? '· ${s.subject}' : ''}'),
                    subtitle: Text(
                        '${DateFormat('MM.dd (E) HH:mm', 'ko').format(s.date)}'
                        '${exam != null ? ' · ${exam.name}' : ''}'
                        '${s.memo.isNotEmpty ? '\n${s.memo}' : ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => app.deleteSession(s.id),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final app = context.read<AppProvider>();
    final minCtrl = TextEditingController();
    final subjCtrl = TextEditingController();
    final memoCtrl = TextEditingController();
    String? examId;
    DateTime date = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('학습 기록 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: examId,
                  decoration: const InputDecoration(labelText: '시험'),
                  items: [
                    const DropdownMenuItem<String>(
                        value: null, child: Text('일반 학습')),
                    ...app.exams.map((e) =>
                        DropdownMenuItem(value: e.id, child: Text(e.name))),
                  ],
                  onChanged: (v) => setState(() => examId = v),
                ),
                TextField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '학습 시간 (분) *'),
                ),
                TextField(
                  controller: subjCtrl,
                  decoration: const InputDecoration(labelText: '과목/내용'),
                ),
                TextField(
                  controller: memoCtrl,
                  decoration: const InputDecoration(labelText: '메모'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('날짜: '),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => date = picked);
                      },
                      child: Text(DateFormat('yyyy.MM.dd').format(date)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            FilledButton(
              onPressed: () {
                final min = int.tryParse(minCtrl.text) ?? 0;
                if (min <= 0) return;
                app.addSession(StudySession(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  examId: examId ?? '',
                  date: date,
                  minutes: min,
                  subject: subjCtrl.text.trim(),
                  memo: memoCtrl.text.trim(),
                ));
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
