import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authCommand = ref.watch(authControllerProvider);
    final authController = ref.read(authControllerProvider.notifier);
    final String? errorMessage = authController.errorMessage;

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
                    'ログインしてクイズを開始',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (errorMessage != null) ...<Widget>[
                    Text(
                      errorMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    onPressed: authCommand.isLoading
                        ? null
                        : () => authController.signInAnonymously(),
                    child: authCommand.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('匿名ログイン'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: null,
                    child: const Text('Google でログイン'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: null,
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
