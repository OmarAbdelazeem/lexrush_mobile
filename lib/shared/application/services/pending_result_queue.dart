import 'dart:convert';

import 'package:lexrush/shared/data/backend/submit_game_result_dtos.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingGameResult {
  const PendingGameResult({
    required this.id,
    required this.userId,
    required this.gameId,
    required this.sessionId,
    required this.request,
    required this.createdAt,
    required this.enqueuedAt,
    required this.retryCount,
    this.lastAttemptAt,
  });

  final String id;
  final String userId;
  final String gameId;
  final String sessionId;
  final SubmitGameResultRequest request;
  final DateTime createdAt;
  final DateTime enqueuedAt;
  final int retryCount;
  final DateTime? lastAttemptAt;

  PendingGameResult copyWith({
    SubmitGameResultRequest? request,
    DateTime? createdAt,
    DateTime? enqueuedAt,
    int? retryCount,
    DateTime? lastAttemptAt,
  }) {
    return PendingGameResult(
      id: id,
      userId: userId,
      gameId: gameId,
      sessionId: sessionId,
      request: request ?? this.request,
      createdAt: createdAt ?? this.createdAt,
      enqueuedAt: enqueuedAt ?? this.enqueuedAt,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'gameId': gameId,
      'sessionId': sessionId,
      'request': request.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'enqueuedAt': enqueuedAt.toIso8601String(),
      'retryCount': retryCount,
      if (lastAttemptAt != null)
        'lastAttemptAt': lastAttemptAt!.toIso8601String(),
    };
  }

  static PendingGameResult? tryFromJson(Object? raw) {
    try {
      if (raw is! Map<String, dynamic>) return null;
      final Object? requestJson = raw['request'];
      if (requestJson is! Map<String, dynamic>) return null;
      return PendingGameResult(
        id: raw['id'] as String,
        userId: raw['userId'] as String,
        gameId: raw['gameId'] as String,
        sessionId: raw['sessionId'] as String,
        request: SubmitGameResultRequest.fromJson(requestJson),
        createdAt: DateTime.parse(raw['createdAt'] as String),
        enqueuedAt: DateTime.parse(raw['enqueuedAt'] as String),
        retryCount: raw['retryCount'] as int,
        lastAttemptAt: raw['lastAttemptAt'] == null
            ? null
            : DateTime.parse(raw['lastAttemptAt'] as String),
      );
    } on Object {
      return null;
    }
  }
}

abstract interface class PendingResultQueue {
  Future<void> enqueueOrUpdate(PendingGameResult item);
  Future<List<PendingGameResult>> loadAll();
  Future<void> remove(String id);
  Future<void> update(PendingGameResult item);
  Future<void> removeForUser(String userId);
}

class SharedPreferencesPendingResultQueue implements PendingResultQueue {
  const SharedPreferencesPendingResultQueue({
    required SharedPreferencesAsync preferences,
    this.maxItems = 50,
  }) : _preferences = preferences;

  static const String storageKey = 'lexrush.pending_results.v1';

  final SharedPreferencesAsync _preferences;
  final int maxItems;

  @override
  Future<void> enqueueOrUpdate(PendingGameResult item) async {
    final List<PendingGameResult> items = await loadAll();
    final int existingIndex = items.indexWhere(
      (PendingGameResult existing) =>
          existing.userId == item.userId &&
          existing.sessionId == item.sessionId,
    );
    if (existingIndex == -1) {
      items.add(item);
    } else {
      final PendingGameResult existing = items[existingIndex];
      items[existingIndex] = PendingGameResult(
        id: existing.id,
        userId: existing.userId,
        gameId: existing.gameId,
        sessionId: existing.sessionId,
        request: item.request,
        createdAt: existing.createdAt,
        enqueuedAt: existing.enqueuedAt,
        retryCount: existing.retryCount,
        lastAttemptAt: existing.lastAttemptAt,
      );
    }
    await _save(_bounded(items));
  }

  @override
  Future<List<PendingGameResult>> loadAll() async {
    final String? raw = await _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return <PendingGameResult>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        await _save(<PendingGameResult>[]);
        return <PendingGameResult>[];
      }
      final List<PendingGameResult> parsed = decoded
          .map(PendingGameResult.tryFromJson)
          .whereType<PendingGameResult>()
          .toList();
      final List<PendingGameResult> bounded = _bounded(parsed);
      if (parsed.length != decoded.length || bounded.length != parsed.length) {
        await _save(bounded);
      }
      return bounded;
    } on Object {
      await _save(<PendingGameResult>[]);
      return <PendingGameResult>[];
    }
  }

  @override
  Future<void> remove(String id) async {
    final List<PendingGameResult> items = await loadAll();
    items.removeWhere((PendingGameResult item) => item.id == id);
    await _save(items);
  }

  @override
  Future<void> update(PendingGameResult item) async {
    final List<PendingGameResult> items = await loadAll();
    final int index = items.indexWhere(
      (PendingGameResult existing) => existing.id == item.id,
    );
    if (index == -1) return;
    items[index] = item;
    await _save(_bounded(items));
  }

  @override
  Future<void> removeForUser(String userId) async {
    final List<PendingGameResult> items = await loadAll();
    items.removeWhere((PendingGameResult item) => item.userId == userId);
    await _save(items);
  }

  List<PendingGameResult> _bounded(List<PendingGameResult> items) {
    if (items.length <= maxItems) return items;
    final List<PendingGameResult> sorted = List<PendingGameResult>.from(items)
      ..sort(
        (PendingGameResult a, PendingGameResult b) =>
            a.enqueuedAt.compareTo(b.enqueuedAt),
      );
    return sorted.skip(sorted.length - maxItems).toList(growable: false);
  }

  Future<void> _save(List<PendingGameResult> items) {
    return _preferences.setString(
      storageKey,
      jsonEncode(items.map((PendingGameResult item) => item.toJson()).toList()),
    );
  }
}
