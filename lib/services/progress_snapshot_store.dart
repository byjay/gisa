import 'dart:convert';

import 'package:hive/hive.dart';

import 'secure_box_service.dart';
import 'user_data_scope.dart';

/// Local persistence boundary for the allowlisted progress exchanged with Worker.
/// Question bodies, answers, explanations, and wrong-note memos are excluded.
class ProgressSnapshotStore {
  ProgressSnapshotStore._();

  static const _sessionTombstonesKey = 'deleted_sessions';
  static const _quizTombstonesKey = 'deleted_quiz_results';
  static const _registrationTombstonesKey = 'deleted_registrations';
  static const _lastDaySyncTimestampKey = '__meta_last_day_updated_at';
  static const _levelSyncTimestampKey = '__meta_level_updated_at';
  static const _safeProgressItemFields = {
    'wrong',
    'correct',
    'last',
    'bookmarked',
    'subject',
    'topic',
    'reps',
    'streak',
    'box',
    'nextDue',
    'updatedAt',
    'reasons',
    'lastReason',
  };

  static Future<Map<String, dynamic>> read() async {
    final ownerId = UserDataScope.ownerId;
    final itemBoxName = UserDataScope.boxNameForOwner(
      'questionProgress',
      ownerId,
    );
    final sessionsBoxName = UserDataScope.boxNameForOwner('sessions', ownerId);
    final quizBoxName = UserDataScope.boxNameForOwner('quizResults', ownerId);
    final flashcardBoxName = UserDataScope.boxNameForOwner(
      'flashcardSrs',
      ownerId,
    );
    final scoreBoxName = UserDataScope.boxNameForOwner('scoreHistory', ownerId);
    final slideBoxName = UserDataScope.boxNameForOwner(
      'slideProgress',
      ownerId,
    );
    final registrationBoxName = UserDataScope.boxNameForOwner(
      'exam_registrations',
      ownerId,
    );
    final metaBoxName = UserDataScope.boxNameForOwner(
      'progressSyncMeta',
      ownerId,
    );
    final itemBox = await Hive.openBox(itemBoxName);
    final sessionsBox = await _secureBox(sessionsBoxName);
    final quizBox = await _secureBox(quizBoxName);
    final flashcardBox = await Hive.openBox(flashcardBoxName);
    final scoreBox = await Hive.openBox(scoreBoxName);
    final slideBox = await Hive.openBox(slideBoxName);
    final registrationBox = await _secureBox(registrationBoxName);
    final metaBox = await _secureBox(metaBoxName);
    final registrationTombstones = _registrationTombstones(
      metaBox.get(_registrationTombstonesKey),
    );
    if (metaBox.get(_registrationTombstonesKey) is Iterable) {
      await metaBox.put(
        _registrationTombstonesKey,
        _serializeRegistrationTombstones(registrationTombstones),
      );
    }

    return {
      'items': _progressItems(itemBox),
      'sessions': _sessionRecords(sessionsBox),
      'quizResults': _quizRecords(quizBox),
      'flashcards': _flashcardRecords(flashcardBox),
      'scores': _scoreRecords(scoreBox),
      'slides': _slideValues(slideBox),
      'registrations': _registrationRecords(registrationBox),
      'deleted': {
        'sessions': _stringSet(metaBox.get(_sessionTombstonesKey)),
        'quizResults': _stringSet(metaBox.get(_quizTombstonesKey)),
        'registrations': _serializeRegistrationTombstones(
          registrationTombstones,
        ),
      },
    };
  }

  static Future<void> markDeleted(String collection, String id) async {
    final key = switch (collection) {
      'sessions' => _sessionTombstonesKey,
      'quizResults' => _quizTombstonesKey,
      'registrations' => _registrationTombstonesKey,
      _ => throw ArgumentError.value(collection, 'collection'),
    };
    final ownerId = UserDataScope.ownerId;
    final generation = UserDataScope.generation;
    final box = await _secureBox(
      UserDataScope.boxNameForOwner('progressSyncMeta', ownerId),
    );
    if (generation != UserDataScope.generation ||
        ownerId != UserDataScope.ownerId) {
      return;
    }
    if (collection == 'registrations') {
      final values = _registrationTombstones(box.get(key));
      final nextAt = _timestamp(DateTime.now().millisecondsSinceEpoch);
      final previousAt = values[id] ?? 0;
      values[id] = nextAt > previousAt ? nextAt : previousAt + 1;
      await box.put(key, _serializeRegistrationTombstones(values));
    } else {
      final values = _stringSet(box.get(key))..add(id);
      await box.put(key, values.toList()..sort());
    }
  }

  static Future<int?> registrationSaveTimestamp(
    String id,
    int proposedAt,
  ) async {
    final ownerId = UserDataScope.ownerId;
    final generation = UserDataScope.generation;
    final box = await _secureBox(
      UserDataScope.boxNameForOwner('progressSyncMeta', ownerId),
    );
    if (generation != UserDataScope.generation ||
        ownerId != UserDataScope.ownerId) {
      return null;
    }
    final rawTombstones = box.get(_registrationTombstonesKey);
    final tombstones = _registrationTombstones(rawTombstones);
    if (rawTombstones is Iterable) {
      await box.put(
        _registrationTombstonesKey,
        _serializeRegistrationTombstones(tombstones),
      );
    }
    final deletedAt = tombstones[id];
    if (deletedAt == null || proposedAt > deletedAt) return proposedAt;
    return deletedAt + 1;
  }

  static Future<void> mergeRemote(Map<String, dynamic> snapshot) async {
    final ownerId = UserDataScope.ownerId;
    final generation = UserDataScope.generation;
    final boxNames = <String, String>{
      'items': UserDataScope.boxNameForOwner('questionProgress', ownerId),
      'sessions': UserDataScope.boxNameForOwner('sessions', ownerId),
      'quizResults': UserDataScope.boxNameForOwner('quizResults', ownerId),
      'flashcards': UserDataScope.boxNameForOwner('flashcardSrs', ownerId),
      'scores': UserDataScope.boxNameForOwner('scoreHistory', ownerId),
      'slides': UserDataScope.boxNameForOwner('slideProgress', ownerId),
      'registrations': UserDataScope.boxNameForOwner(
        'exam_registrations',
        ownerId,
      ),
      'meta': UserDataScope.boxNameForOwner('progressSyncMeta', ownerId),
    };
    final itemBox = await Hive.openBox(boxNames['items']!);
    final sessionsBox = await _secureBox(boxNames['sessions']!);
    final quizBox = await _secureBox(boxNames['quizResults']!);
    final flashcardBox = await Hive.openBox(boxNames['flashcards']!);
    final scoreBox = await Hive.openBox(boxNames['scores']!);
    final slideBox = await Hive.openBox(boxNames['slides']!);
    final registrationBox = await _secureBox(boxNames['registrations']!);
    final metaBox = await _secureBox(boxNames['meta']!);
    if (generation != UserDataScope.generation ||
        ownerId != UserDataScope.ownerId) {
      return;
    }

    final remoteDeleted = _deleted(snapshot['deleted']);
    final deleted = <String, Set<String>>{
      'sessions': _stringSet(metaBox.get(_sessionTombstonesKey))
        ..addAll(remoteDeleted['sessions']!),
      'quizResults': _stringSet(metaBox.get(_quizTombstonesKey))
        ..addAll(remoteDeleted['quizResults']!),
    };
    final registrationTombstones = _registrationTombstones(
      metaBox.get(_registrationTombstonesKey),
    );
    final rawRemoteDeleted = snapshot['deleted'];
    final remoteRegistrationTombstones = rawRemoteDeleted is Map
        ? _registrationTombstones(rawRemoteDeleted['registrations'])
        : <String, int>{};
    for (final entry in remoteRegistrationTombstones.entries) {
      final localAt = registrationTombstones[entry.key] ?? -1;
      if (entry.value > localAt) {
        registrationTombstones[entry.key] = entry.value;
      }
    }
    await metaBox.put(
      _sessionTombstonesKey,
      deleted['sessions']!.toList()..sort(),
    );
    await metaBox.put(
      _quizTombstonesKey,
      deleted['quizResults']!.toList()..sort(),
    );

    for (final id in deleted['sessions']!) {
      await sessionsBox.delete(id);
    }
    for (final id in deleted['quizResults']!) {
      await quizBox.delete(id);
    }
    final remoteItems = snapshot['items'];
    if (remoteItems is Map) {
      for (final entry in remoteItems.entries) {
        if (entry.key is! String || entry.value is! Map) continue;
        final qid = entry.key as String;
        final remote = _pickFields(
          Map<String, dynamic>.from(entry.value as Map),
          _safeProgressItemFields,
        );
        final rawLocal = itemBox.get(qid);
        final local = rawLocal is Map
            ? Map<String, dynamic>.from(rawLocal)
            : null;
        if (local == null ||
            _timestamp(remote['updatedAt']) > _timestamp(local['updatedAt'])) {
          await itemBox.put(qid, remote);
        }
      }
    }

    await _mergeRecords(
      sessionsBox,
      snapshot['sessions'],
      deleted['sessions']!,
      const {'id', 'examId', 'date', 'minutes', 'updatedAt'},
    );
    await _mergeRecords(
      quizBox,
      snapshot['quizResults'],
      deleted['quizResults']!,
      const {
        'id',
        'title',
        'total',
        'correct',
        'date',
        'updatedAt',
        'subjectTotal',
        'subjectCorrect',
      },
    );
    await _mergeRecords(flashcardBox, snapshot['flashcards'], const {}, const {
      'id',
      'box',
      'nextDue',
      'seen',
      'known',
      'updatedAt',
    });
    await _mergeScores(scoreBox, snapshot['scores']);
    await _mergeSlides(slideBox, snapshot['slides']);
    await _mergeRegistrationRecords(
      registrationBox,
      snapshot['registrations'],
      registrationTombstones,
    );
    await metaBox.put(
      _registrationTombstonesKey,
      _serializeRegistrationTombstones(registrationTombstones),
    );
  }

  static Future<Box> _secureBox(String boxName) =>
      SecureBoxService.instance.openSecureBox(boxName);

  static Map<String, dynamic> _progressItems(Box box) {
    final out = <String, dynamic>{};
    for (final key in box.keys) {
      final value = box.get(key);
      if (key is String && value is Map) {
        out[key] = _pickFields(
          Map<String, dynamic>.from(value),
          _safeProgressItemFields,
        );
      }
    }
    return out;
  }

  static List<Map<String, dynamic>> _sessionRecords(Box box) =>
      _records(box, const {'examId', 'date', 'minutes', 'updatedAt'});

  static List<Map<String, dynamic>> _quizRecords(Box box) =>
      _records(box, const {
        'title',
        'total',
        'correct',
        'date',
        'updatedAt',
        'subjectTotal',
        'subjectCorrect',
      });

  static List<Map<String, dynamic>> _flashcardRecords(Box box) =>
      _records(box, const {'box', 'nextDue', 'seen', 'known', 'updatedAt'});

  static List<Map<String, dynamic>> _scoreRecords(Box box) {
    final out = <Map<String, dynamic>>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (key is! String || raw is! Map || !_isDayId(key)) continue;
      final record = Map<String, dynamic>.from(raw);
      final scoreMilli = record['scoreMilli'];
      final score = record['score'];
      final attempts = record['attempts'];
      final normalizedScoreMilli = scoreMilli is int
          ? scoreMilli
          : score is num &&
                score.toDouble().isFinite &&
                score >= 0 &&
                score <= 100
          ? (score * 1000).round()
          : null;
      if (normalizedScoreMilli == null ||
          normalizedScoreMilli < 0 ||
          normalizedScoreMilli > 100000 ||
          attempts is! int ||
          attempts < 0) {
        continue;
      }
      out.add({
        'id': key,
        'scoreMilli': normalizedScoreMilli,
        'attempts': attempts,
        'updatedAt': _timestamp(record['updatedAt'] ?? record['ts']),
      });
    }
    return out;
  }

  static Map<String, dynamic> _slideValues(Box box) {
    final out = <String, dynamic>{};
    for (final key in box.keys.whereType<String>()) {
      final value = box.get(key);
      if (_isSlideCountKey(key) && value is int && value >= 0) {
        out[key] = value;
      } else if (key == 'lastDay' && value is int && value >= 0) {
        out[key] = value;
        out['lastDayUpdatedAt'] = _timestamp(box.get(_lastDaySyncTimestampKey));
      } else if (key == 'level' && value is String && _isStudyLevel(value)) {
        out['level'] = value;
        out['levelUpdatedAt'] = _timestamp(box.get(_levelSyncTimestampKey));
      }
    }
    return out;
  }

  static List<Map<String, dynamic>> _registrationRecords(Box box) =>
      _records(box, const {
        'jmCd',
        'catalogId',
        'certName',
        'roundLabel',
        'phase',
        'status',
        'scoredTotal',
        'scoredCorrect',
        'subjectFails',
        'scoredAt',
        'updatedAt',
      });

  static List<Map<String, dynamic>> _records(Box box, Set<String> fields) {
    final out = <Map<String, dynamic>>[];
    for (final key in box.keys) {
      final value = box.get(key);
      if (value is Map) {
        final record = _pickFields(Map<String, dynamic>.from(value), fields);
        record.putIfAbsent('id', () => key.toString());
        out.add(record);
      }
    }
    return out;
  }

  static Map<String, dynamic> _pickFields(
    Map<String, dynamic> source,
    Set<String> allowed,
  ) => {
    for (final entry in source.entries)
      if (allowed.contains(entry.key) && entry.value != null)
        entry.key: entry.value,
  };

  static Future<void> _mergeRecords(
    Box box,
    Object? incoming,
    Set<String> deleted,
    Set<String> allowedFields,
  ) async {
    if (incoming is! List) return;
    for (final value in incoming) {
      if (value is! Map) continue;
      final record = Map<String, dynamic>.from(value);
      final id = record['id'];
      if (id is! String || id.isEmpty || deleted.contains(id)) continue;
      final rawLocal = box.get(id);
      final local = rawLocal is Map
          ? Map<String, dynamic>.from(rawLocal)
          : null;
      final safeRecord = _pickFields(record, allowedFields)..['id'] = id;
      Map<String, dynamic>? localSafe;
      if (local != null) {
        localSafe = _pickFields(local, allowedFields)..['id'] = id;
      }
      final remoteAt = _timestamp(record['updatedAt'] ?? record['date']);
      final localAt = _timestamp(local?['updatedAt'] ?? local?['date']);
      if (local == null ||
          remoteAt > localAt ||
          (remoteAt == localAt &&
              _stableJson(safeRecord).compareTo(_stableJson(localSafe)) > 0)) {
        await box.put(id, safeRecord);
      }
    }
  }

  static Future<void> _mergeRegistrationRecords(
    Box box,
    Object? incoming,
    Map<String, int> deletedAt,
  ) async {
    const allowedFields = {
      'id',
      'jmCd',
      'catalogId',
      'certName',
      'roundLabel',
      'phase',
      'status',
      'scoredTotal',
      'scoredCorrect',
      'subjectFails',
      'scoredAt',
      'updatedAt',
    };
    final candidates = <String, Map<String, dynamic>>{};

    void consider(Map<String, dynamic> source, String fallbackId) {
      final rawId = source['id'] ?? fallbackId;
      if (rawId is! String || rawId.isEmpty) return;
      final record = _pickFields(source, allowedFields)..['id'] = rawId;
      final previous = candidates[rawId];
      final recordAt = _timestamp(record['updatedAt']);
      final previousAt = _timestamp(previous?['updatedAt']);
      if (previous == null ||
          recordAt > previousAt ||
          (recordAt == previousAt &&
              _stableJson(record).compareTo(_stableJson(previous)) > 0)) {
        candidates[rawId] = record;
      }
    }

    for (final key in box.keys) {
      final value = box.get(key);
      if (value is Map) {
        consider(Map<String, dynamic>.from(value), key.toString());
      }
    }
    if (incoming is List) {
      for (final value in incoming) {
        if (value is Map) consider(Map<String, dynamic>.from(value), '');
      }
    }

    for (final entry in deletedAt.entries.toList()) {
      final record = candidates[entry.key];
      if (record != null && _timestamp(record['updatedAt']) > entry.value) {
        deletedAt.remove(entry.key);
      } else {
        candidates.remove(entry.key);
        await box.delete(entry.key);
      }
    }
    for (final entry in candidates.entries) {
      if (!deletedAt.containsKey(entry.key)) {
        await box.put(entry.key, entry.value);
      }
    }
  }

  static Future<void> _mergeScores(Box box, Object? incoming) async {
    if (incoming is! List) return;
    for (final value in incoming) {
      if (value is! Map) continue;
      final remote = Map<String, dynamic>.from(value);
      final id = remote['id'];
      final scoreMilli = remote['scoreMilli'];
      final attempts = remote['attempts'];
      if (id is! String ||
          !_isDayId(id) ||
          scoreMilli is! int ||
          scoreMilli < 0 ||
          scoreMilli > 100000 ||
          attempts is! int ||
          attempts < 0) {
        continue;
      }
      final localValue = box.get(id);
      final local = localValue is Map
          ? Map<String, dynamic>.from(localValue)
          : null;
      final remoteUpdatedAt = _timestamp(remote['updatedAt']);
      final localScoreMilli = local?['scoreMilli'];
      final localScore = local?['score'];
      final normalizedLocalScoreMilli = localScoreMilli is int
          ? localScoreMilli
          : localScore is num && localScore.toDouble().isFinite
          ? (localScore * 1000).round()
          : -1;
      final localCanonical = {
        'id': id,
        'scoreMilli': normalizedLocalScoreMilli,
        'attempts': local?['attempts'],
        'updatedAt': _timestamp(local?['updatedAt'] ?? local?['ts']),
      };
      final remoteCanonical = {
        'id': id,
        'scoreMilli': scoreMilli,
        'attempts': attempts,
        'updatedAt': remoteUpdatedAt,
      };
      if (local == null ||
          remoteUpdatedAt > _timestamp(local['updatedAt'] ?? local['ts']) ||
          (remoteUpdatedAt == _timestamp(local['updatedAt'] ?? local['ts']) &&
              _stableJson(
                    remoteCanonical,
                  ).compareTo(_stableJson(localCanonical)) >
                  0)) {
        await box.put(id, {
          'scoreMilli': scoreMilli,
          'attempts': attempts,
          'ts': DateTime.fromMillisecondsSinceEpoch(
            remoteUpdatedAt,
          ).toIso8601String(),
          'updatedAt': remoteUpdatedAt,
        });
      }
    }
  }

  static Future<void> _mergeSlides(Box box, Object? incoming) async {
    if (incoming is! Map) return;
    for (final entry in incoming.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String) continue;
      if (_isSlideCountKey(key)) {
        if (value is! int || value < 0) continue;
        final current = box.get(key);
        final local = current is int && current > 0 ? current : 0;
        if (value > local) await box.put(key, value);
      } else if (key == 'lastDay') {
        if (value is! int || value < 0) continue;
        final remoteAt = _timestamp(incoming['lastDayUpdatedAt']);
        final localAt = _timestamp(box.get(_lastDaySyncTimestampKey));
        final current = box.get('lastDay');
        final localValue = current is int ? current : -1;
        if (remoteAt > localAt || (remoteAt == localAt && value > localValue)) {
          await box.put('lastDay', value);
          await box.put(_lastDaySyncTimestampKey, remoteAt);
        }
      } else if (key == 'level') {
        if (value is! String || !_isStudyLevel(value)) continue;
        final remoteAt = _timestamp(incoming['levelUpdatedAt']);
        final localAt = _timestamp(box.get(_levelSyncTimestampKey));
        final current = box.get('level');
        final localValue = current is String ? current : '';
        if (remoteAt > localAt ||
            (remoteAt == localAt && value.compareTo(localValue) > 0)) {
          await box.put('level', value);
          await box.put(_levelSyncTimestampKey, remoteAt);
        }
      }
    }
  }

  static Map<String, Set<String>> _deleted(Object? value) {
    if (value is! Map) {
      return {'sessions': <String>{}, 'quizResults': <String>{}};
    }
    return {
      'sessions': _stringSet(value['sessions']),
      'quizResults': _stringSet(value['quizResults']),
    };
  }

  static Map<String, int> _registrationTombstones(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          if (entry.key is String && entry.value is int && entry.value >= 0)
            entry.key as String: entry.value as int,
      };
    }
    if (value is Iterable) {
      final migratedAt = DateTime.now().millisecondsSinceEpoch;
      return {for (final id in value.whereType<String>()) id: migratedAt};
    }
    return {};
  }

  static Map<String, int> _serializeRegistrationTombstones(
    Map<String, int> values,
  ) {
    final ids = values.keys.toList()..sort();
    return {for (final id in ids) id: values[id]!};
  }

  static Set<String> _stringSet(Object? value) =>
      value is Iterable ? value.whereType<String>().toSet() : <String>{};

  static bool _isDayId(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);

  static bool _isSlideCountKey(String value) =>
      value.length <= 200 &&
      RegExp(r'^seen_[a-zA-Z0-9_-]*\d+$').hasMatch(value);

  static bool _isStudyLevel(String value) =>
      const {'baby', 'standard', 'fast'}.contains(value);

  static String _stableJson(Object? value) => jsonEncode(_sortJson(value));

  static Object? _sortJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.whereType<String>().toList()..sort();
      return {for (final key in keys) key: _sortJson(value[key])};
    }
    if (value is Iterable) return value.map(_sortJson).toList();
    return value;
  }

  static int _timestamp(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ??
          DateTime.tryParse(value)?.millisecondsSinceEpoch ??
          0;
    }
    return 0;
  }
}
