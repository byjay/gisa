import 'package:flutter/material.dart';

class Exam {
  final String id;
  String name;
  String category;
  DateTime examDate;
  String memo;
  int colorValue;

  Exam({
    required this.id,
    required this.name,
    this.category = '',
    required this.examDate,
    this.memo = '',
    this.colorValue = 0xFF5C6BC0,
  });

  Color get color => Color(colorValue);

  int get dDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(examDate.year, examDate.month, examDate.day);
    return target.difference(today).inDays;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'examDate': examDate.toIso8601String(),
    'memo': memo,
    'colorValue': colorValue,
  };

  factory Exam.fromMap(Map<dynamic, dynamic> m) => Exam(
    id: m['id'] as String,
    name: (m['name'] as String?) ?? '',
    category: (m['category'] as String?) ?? '',
    examDate: DateTime.parse(m['examDate'] as String),
    memo: (m['memo'] as String?) ?? '',
    colorValue: (m['colorValue'] as int?) ?? 0xFF5C6BC0,
  );
}

class StudySession {
  final String id;
  String examId;
  DateTime date;
  int minutes;
  String subject;
  String memo;

  StudySession({
    required this.id,
    required this.examId,
    required this.date,
    required this.minutes,
    this.subject = '',
    this.memo = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'examId': examId,
    'date': date.toIso8601String(),
    'minutes': minutes,
    'subject': subject,
    'memo': memo,
  };

  factory StudySession.fromMap(Map<dynamic, dynamic> m) => StudySession(
    id: m['id'] as String,
    examId: (m['examId'] as String?) ?? '',
    date: DateTime.parse(m['date'] as String),
    minutes: (m['minutes'] as int?) ?? 0,
    subject: (m['subject'] as String?) ?? '',
    memo: (m['memo'] as String?) ?? '',
  );
}

class WrongNote {
  final String id;
  String examId;
  String question;
  String answer;
  String memo;
  bool mastered;
  DateTime createdAt;

  WrongNote({
    required this.id,
    required this.examId,
    required this.question,
    required this.answer,
    this.memo = '',
    this.mastered = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'examId': examId,
    'question': question,
    'answer': answer,
    'memo': memo,
    'mastered': mastered,
    'createdAt': createdAt.toIso8601String(),
  };

  factory WrongNote.fromMap(Map<dynamic, dynamic> m) => WrongNote(
    id: m['id'] as String,
    examId: (m['examId'] as String?) ?? '',
    question: (m['question'] as String?) ?? '',
    answer: (m['answer'] as String?) ?? '',
    memo: (m['memo'] as String?) ?? '',
    mastered: (m['mastered'] as bool?) ?? false,
    createdAt: DateTime.parse(m['createdAt'] as String),
  );
}
