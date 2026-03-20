class AuthState {
  const AuthState({
    required this.uid,
    required this.providerIds,
    required this.providerLabel,
    required this.isAnonymous,
  });

  const AuthState.signedOut()
    : uid = null,
      providerIds = const <String>[],
      providerLabel = null,
      isAnonymous = false;

  final String? uid;
  final List<String> providerIds;
  final String? providerLabel;
  final bool isAnonymous;

  bool get isSignedIn => uid != null;
}
