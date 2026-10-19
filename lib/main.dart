import 'package:flutter/material.dart';

import 'screens/intro_screen.dart';

void main() {
  runApp(const AthleteApp());
}

class AthleteApp extends StatelessWidget {
  const AthleteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Athlete App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF00897B),
        useMaterial3: true,
      ),
      home: const IntroScreen(),
    );
  }
}
