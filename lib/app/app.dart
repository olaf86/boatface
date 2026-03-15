import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_screen.dart';

class BoatfaceApp extends ConsumerWidget {
  const BoatfaceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    return MaterialApp(
      title: 'Boatface',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A5A8A)),
        useMaterial3: true,
      ),
      home: authState.isSignedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
