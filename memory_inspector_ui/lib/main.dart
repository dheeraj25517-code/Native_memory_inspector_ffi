import 'package:flutter/material.dart';
// Ensure this path matches your project's filename exactly
import 'package:memory_inspector_devtools/InspectorScreen.dart';

void main() {
  runApp(const MemoryInspectorApp());
}

class MemoryInspectorApp extends StatelessWidget {
  const MemoryInspectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Native Memory Inspector',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0221),
        primaryColor: Colors.purple,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF160633),
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.purpleAccent,
          secondary: Colors.cyanAccent,
        ),
      ),
      // Direct launch into your Inspector logic
      home: const InspectorScreen(),
    );
  }
}