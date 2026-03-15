import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({required this.onSignedIn, super.key});

  final ValueChanged<String> onSignedIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Boatface',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ログイン',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => onSignedIn('ゲストログイン'),
                    child: const Text('ゲストアカウントでログイン'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => onSignedIn('Google'),
                    child: const Text('Google でログイン'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => onSignedIn('GameCenter'),
                    child: const Text('GameCenter でログイン'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
