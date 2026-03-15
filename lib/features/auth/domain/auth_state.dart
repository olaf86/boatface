class AuthState {
  const AuthState({this.providerLabel});

  final String? providerLabel;

  bool get isSignedIn => providerLabel != null;

  AuthState copyWith({String? providerLabel, bool clearProvider = false}) {
    return AuthState(
      providerLabel: clearProvider
          ? null
          : (providerLabel ?? this.providerLabel),
    );
  }
}
