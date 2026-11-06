import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hive namespace for user-owned records.
///
/// A null owner is the pre-existing guest namespace, preserving legacy local
/// records. Authenticated account IDs are hashed before becoming box names.
class UserDataScope {
  UserDataScope._();

  static String? _ownerId;
  static int _generation = 0;

  static String? get ownerId => _ownerId;
  static int get generation => _generation;

  static String boxName(String baseName) => boxNameForOwner(baseName, _ownerId);

  static String boxNameForOwner(String baseName, String? ownerId) {
    final normalized = ownerId?.trim();
    if (normalized == null || normalized.isEmpty) return baseName;
    final digest = sha256.convert(utf8.encode(normalized)).toString();
    return '${baseName}__account_$digest';
  }

  static bool activate(String? ownerId) {
    final normalized = ownerId?.trim();
    final nextOwner = normalized == null || normalized.isEmpty
        ? null
        : normalized;
    if (_ownerId == nextOwner) return false;
    _ownerId = nextOwner;
    _generation++;
    return true;
  }
}
