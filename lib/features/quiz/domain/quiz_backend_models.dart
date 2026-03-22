class QuizSessionLease {
  const QuizSessionLease({required this.sessionId, required this.expiresAt});

  final String sessionId;
  final DateTime expiresAt;
}

class QuizResultSubmissionReceipt {
  const QuizResultSubmissionReceipt({
    required this.resultId,
    required this.rankingEligible,
    required this.periodKeyDaily,
    required this.periodKeyTerm,
  });

  final String resultId;
  final bool rankingEligible;
  final String periodKeyDaily;
  final String periodKeyTerm;
}
