import '../../profile/domain/user_profile.dart';

enum RankingPeriod { today, term }

extension RankingPeriodX on RankingPeriod {
  String get id => switch (this) {
    RankingPeriod.today => 'today',
    RankingPeriod.term => 'term',
  };

  String get label => switch (this) {
    RankingPeriod.today => '本日ランキング',
    RankingPeriod.term => '期別ランキング',
  };

  static RankingPeriod? fromId(String id) {
    for (final RankingPeriod item in RankingPeriod.values) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }
}

class RankingRequest {
  const RankingRequest({
    required this.modeId,
    required this.period,
    this.limit = 50,
  });

  final String modeId;
  final RankingPeriod period;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is RankingRequest &&
        other.modeId == modeId &&
        other.period == period &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(modeId, period, limit);
}

class RankingEntry {
  const RankingEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.region,
    required this.score,
    required this.totalAnswerTimeMs,
  });

  final int rank;
  final String userId;
  final String displayName;
  final UserRegion? region;
  final int score;
  final int totalAnswerTimeMs;

  static RankingEntry? tryParseJson(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return null;
    }

    final int? rank = value['rank'] as int?;
    final String? userId = value['userId'] as String?;
    final String? displayName = value['displayName'] as String?;
    final int? score = value['score'] as int?;
    final int? totalAnswerTimeMs = value['totalAnswerTimeMs'] as int?;
    if (rank == null ||
        userId == null ||
        displayName == null ||
        score == null ||
        totalAnswerTimeMs == null) {
      return null;
    }

    return RankingEntry(
      rank: rank,
      userId: userId,
      displayName: displayName,
      region: UserRegion.tryParseJson(value['region']),
      score: score,
      totalAnswerTimeMs: totalAnswerTimeMs,
    );
  }
}

class RankingSnapshot {
  const RankingSnapshot({
    required this.modeId,
    required this.period,
    required this.generatedAt,
    required this.entries,
  });

  final String modeId;
  final RankingPeriod period;
  final DateTime generatedAt;
  final List<RankingEntry> entries;

  static RankingSnapshot? tryParseJson(Map<String, Object?> json) {
    final String? modeId = json['modeId'] as String?;
    final String? periodId = json['period'] as String?;
    final String? generatedAtText = json['generatedAt'] as String?;
    final Object? entriesValue = json['entries'];
    if (modeId == null ||
        periodId == null ||
        generatedAtText == null ||
        entriesValue is! List<Object?>) {
      return null;
    }

    final RankingPeriod? period = RankingPeriodX.fromId(periodId);
    final DateTime? generatedAt = DateTime.tryParse(generatedAtText)?.toLocal();
    if (period == null || generatedAt == null) {
      return null;
    }

    final List<RankingEntry> entries = entriesValue
        .map(RankingEntry.tryParseJson)
        .whereType<RankingEntry>()
        .toList(growable: false);

    return RankingSnapshot(
      modeId: modeId,
      period: period,
      generatedAt: generatedAt,
      entries: entries,
    );
  }
}
