import 'package:flutter/material.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_screen.dart';

class BoatfaceApp extends StatefulWidget {
  const BoatfaceApp({super.key});

  @override
  State<BoatfaceApp> createState() => _BoatfaceAppState();
}

class _BoatfaceAppState extends State<BoatfaceApp> {
  String? _signedInProvider;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boatface',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A5A8A)),
        useMaterial3: true,
      ),
      home: _signedInProvider == null
          ? LoginScreen(
              onSignedIn: (String provider) {
                setState(() {
                  _signedInProvider = provider;
                });
              },
            )
          : HomeScreen(
              providerLabel: _signedInProvider!,
              onSignOut: () {
                setState(() {
                  _signedInProvider = null;
                });
              },
            ),
    );
  }
}
