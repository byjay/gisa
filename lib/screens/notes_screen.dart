import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _showMastered = true;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final notes = _showMastered
        ? app.notes
        : app.notes.where((n) => !n.mastered).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('오답 노트'),
        actions: [
          Row(
            children: [
              const Text('완료 표시', style: TextStyle(fontSize: 12)),
              Switch(
                value: _showMastered,
                onChanged: (v) => setState(() => _showMastered = v),
              ),
            ],
          ),
        ],
      ),
      body: notes.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quiz, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('오답 노트가 없습니다.\n틀린 문제를 기록하고 복습하세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: notes.length,
              itemBuilder: (context, i) {
                final n = notes[i];
                final exam = app.examById(n.examId);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    leading: Checkbox(
                      value: n.mastered,
                      shape: const CircleBorder(),
                      onChanged: (v) {
                        n.mastered = v ?? false;
                        app.updateNote(n);
                      },
                    ),
                    title: Text(
                      n.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        decoration:
                            n.mastered ? TextDecoration.lineThrough : null,
                        color: n.mastered ? Colors.grey : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: exam != null
                        ? Text(exam.name,
                            style: TextStyle(color: exam.color, fontSize: 12))
                        : null,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('정답',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green)),
                                  const SizedBox(height: 4),
                                  Text(n.answer),
                                ],
                              ),
                            ),
                            if (n.memo.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('메모: ${n.memo}',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13)),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () =>
                                      _showNoteDialog(context, note: n),
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('수정'),
                                ),
                                TextButton.icon(
                                  onPressed: () => app.deleteNote(n.id),
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: const Text('삭제'),
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.red),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNoteDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showNoteDialog(BuildContext context, {WrongNote? note}) {
    final app = context.read<AppProvider>();
    final qCtrl = TextEditingController(text: note?.question ?? '');
    final aCtrl = TextEditingController(text: note?.answer ?? '');
    final mCtrl = TextEditingController(text: note?.memo ?? '');
    String? examId = note?.examId.isNotEmpty == true ? note!.examId : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(note == null ? '오답 추가' : '오답 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: examId,
                  decoration: const InputDecoration(labelText: '시험'),
                  items: [
                    const DropdownMenuItem<String>(
                        value: null, child: Text('일반')),
                    ...app.exams.map((e) =>
                        DropdownMenuItem(value: e.id, child: Text(e.name))),
                  ],
                  onChanged: (v) => setState(() => examId = v),
                ),
                TextField(
                  controller: qCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '문제 *'),
                ),
                TextField(
                  controller: aCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '정답 *'),
                ),
                TextField(
                  controller: mCtrl,
                  decoration: const InputDecoration(labelText: '메모/해설'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            FilledButton(
              onPressed: () {
                if (qCtrl.text.trim().isEmpty || aCtrl.text.trim().isEmpty) {
                  return;
                }
                if (note == null) {
                  app.addNote(WrongNote(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    examId: examId ?? '',
                    question: qCtrl.text.trim(),
                    answer: aCtrl.text.trim(),
                    memo: mCtrl.text.trim(),
                    createdAt: DateTime.now(),
                  ));
                } else {
                  note
                    ..examId = examId ?? ''
                    ..question = qCtrl.text.trim()
                    ..answer = aCtrl.text.trim()
                    ..memo = mCtrl.text.trim();
                  app.updateNote(note);
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
