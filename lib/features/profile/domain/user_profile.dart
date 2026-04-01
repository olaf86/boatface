enum UserRegionCategory { prefecture, other }

class UserRegion {
  const UserRegion({
    required this.category,
    required this.code,
    required this.label,
  });

  final UserRegionCategory category;
  final String code;
  final String label;

  static UserRegion? tryParseJson(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return null;
    }

    final String? categoryId = value['category'] as String?;
    final String? code = value['code'] as String?;
    final String? label = value['label'] as String?;
    if (categoryId == null || code == null || label == null) {
      return null;
    }

    UserRegionCategory? category;
    for (final UserRegionCategory item in UserRegionCategory.values) {
      if (item.id == categoryId) {
        category = item;
        break;
      }
    }
    if (category == null) {
      return null;
    }

    return UserRegion(category: category, code: code, label: label);
  }

  Map<String, Object?> toRequestJson() {
    return <String, Object?>{'category': category.id, 'code': code};
  }
}

extension on UserRegionCategory {
  String get id => switch (this) {
    UserRegionCategory.prefecture => 'prefecture',
    UserRegionCategory.other => 'other',
  };
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.nickname,
    required this.rankingDisplayName,
    required this.region,
    required this.quizProgress,
  });

  final String uid;
  final String displayName;
  final String? nickname;
  final String rankingDisplayName;
  final UserRegion? region;
  final UserQuizProgress quizProgress;

  static UserProfile? tryParseJson(Map<String, Object?> json) {
    final String? uid = json['uid'] as String?;
    final String? displayName = json['displayName'] as String?;
    final String? rankingDisplayName = json['rankingDisplayName'] as String?;
    if (uid == null || displayName == null || rankingDisplayName == null) {
      return null;
    }

    final Object? nicknameValue = json['nickname'];
    final String? nickname = nicknameValue is String ? nicknameValue : null;

    return UserProfile(
      uid: uid,
      displayName: displayName,
      nickname: nickname,
      rankingDisplayName: rankingDisplayName,
      region: UserRegion.tryParseJson(json['region']),
      quizProgress: UserQuizProgress.tryParseJson(json['quizProgress']),
    );
  }
}

class UserQuizProgress {
  const UserQuizProgress({
    required this.totalAttempts,
    required this.attemptCountsByMode,
    required this.clearedModeIds,
    required this.lastAttemptModeId,
    required this.lastClearedModeId,
  });

  const UserQuizProgress.empty()
    : totalAttempts = 0,
      attemptCountsByMode = const <String, int>{},
      clearedModeIds = const <String>[],
      lastAttemptModeId = null,
      lastClearedModeId = null;

  final int totalAttempts;
  final Map<String, int> attemptCountsByMode;
  final List<String> clearedModeIds;
  final String? lastAttemptModeId;
  final String? lastClearedModeId;

  bool hasClearedMode(String modeId) => clearedModeIds.contains(modeId);

  static UserQuizProgress tryParseJson(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return const UserQuizProgress.empty();
    }

    final Object? totalAttemptsValue = value['totalAttempts'];
    final Object? attemptCountsValue = value['attemptCountsByMode'];
    final Object? clearedModeIdsValue = value['clearedModeIds'];

    final Map<String, int> attemptCountsByMode = <String, int>{};
    if (attemptCountsValue is Map<Object?, Object?>) {
      for (final MapEntry<Object?, Object?> entry
          in attemptCountsValue.entries) {
        final Object? rawKey = entry.key;
        final Object? rawValue = entry.value;
        if (rawKey is! String || rawValue is! int || rawValue < 0) {
          continue;
        }
        attemptCountsByMode[rawKey] = rawValue;
      }
    }

    final List<String> clearedModeIds = <String>[
      if (clearedModeIdsValue is List<Object?>)
        for (final Object? item in clearedModeIdsValue)
          if (item is String) item,
    ];

    return UserQuizProgress(
      totalAttempts: totalAttemptsValue is int && totalAttemptsValue >= 0
          ? totalAttemptsValue
          : 0,
      attemptCountsByMode: Map<String, int>.unmodifiable(attemptCountsByMode),
      clearedModeIds: List<String>.unmodifiable(clearedModeIds),
      lastAttemptModeId: value['lastAttemptModeId'] is String
          ? value['lastAttemptModeId'] as String
          : null,
      lastClearedModeId: value['lastClearedModeId'] is String
          ? value['lastClearedModeId'] as String
          : null,
    );
  }
}

const List<UserRegion> kUserRegionOptions = <UserRegion>[
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'hokkaido',
    label: '北海道',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'aomori',
    label: '青森県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'iwate',
    label: '岩手県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'miyagi',
    label: '宮城県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'akita',
    label: '秋田県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'yamagata',
    label: '山形県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'fukushima',
    label: '福島県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'ibaraki',
    label: '茨城県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'tochigi',
    label: '栃木県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'gunma',
    label: '群馬県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'saitama',
    label: '埼玉県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'chiba',
    label: '千葉県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'tokyo',
    label: '東京都',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'kanagawa',
    label: '神奈川県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'niigata',
    label: '新潟県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'toyama',
    label: '富山県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'ishikawa',
    label: '石川県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'fukui',
    label: '福井県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'yamanashi',
    label: '山梨県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'nagano',
    label: '長野県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'gifu',
    label: '岐阜県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'shizuoka',
    label: '静岡県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'aichi',
    label: '愛知県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'mie',
    label: '三重県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'shiga',
    label: '滋賀県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'kyoto',
    label: '京都府',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'osaka',
    label: '大阪府',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'hyogo',
    label: '兵庫県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'nara',
    label: '奈良県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'wakayama',
    label: '和歌山県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'tottori',
    label: '鳥取県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'shimane',
    label: '島根県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'okayama',
    label: '岡山県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'hiroshima',
    label: '広島県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'yamaguchi',
    label: '山口県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'tokushima',
    label: '徳島県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'kagawa',
    label: '香川県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'ehime',
    label: '愛媛県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'kochi',
    label: '高知県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'fukuoka',
    label: '福岡県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'saga',
    label: '佐賀県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'nagasaki',
    label: '長崎県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'kumamoto',
    label: '熊本県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'oita',
    label: '大分県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'miyazaki',
    label: '宮崎県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'kagoshima',
    label: '鹿児島県',
  ),
  UserRegion(
    category: UserRegionCategory.prefecture,
    code: 'okinawa',
    label: '沖縄県',
  ),
  UserRegion(category: UserRegionCategory.other, code: 'overseas', label: '海外'),
  UserRegion(category: UserRegionCategory.other, code: 'other', label: 'その他'),
];
