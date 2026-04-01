import '../../profile/domain/user_profile.dart';
import 'quiz_models.dart';
import 'quiz_modes.dart';

const Set<String> kAlwaysUnlockedQuizModeIds = <String>{'quick', 'custom'};
const Map<String, String> kQuizModeUnlockPrerequisiteIds = <String, String>{
  'careful': 'quick',
  'challenge': 'careful',
  'master': 'challenge',
};

class QuizModeAccess {
  const QuizModeAccess({
    required this.mode,
    required this.isUnlocked,
    required this.isImplemented,
    required this.lockedReason,
  });

  final QuizModeConfig mode;
  final bool isUnlocked;
  final bool isImplemented;
  final String? lockedReason;

  bool get canStart => isUnlocked && isImplemented;
}

QuizModeAccess resolveQuizModeAccess(
  QuizModeConfig mode, {
  required UserQuizProgress? quizProgress,
}) {
  final String? prerequisiteModeId = kQuizModeUnlockPrerequisiteIds[mode.id];
  final bool isUnlocked =
      prerequisiteModeId == null ||
      kAlwaysUnlockedQuizModeIds.contains(mode.id) ||
      (quizProgress?.hasClearedMode(prerequisiteModeId) ?? false);

  final QuizModeConfig? prerequisiteMode = prerequisiteModeId == null
      ? null
      : quizModeById(prerequisiteModeId);

  return QuizModeAccess(
    mode: mode,
    isUnlocked: isUnlocked,
    isImplemented: mode.availableInMvp,
    lockedReason: isUnlocked || prerequisiteMode == null
        ? null
        : '「${prerequisiteMode.label}」を全問クリアで開放',
  );
}
