import 'package:flutter/material.dart';
import 'package:memory_inspector_devtools/InspectorScreen.dart';

void main() {
  runApp(const MemoryInspectorApp());
}

class MemoryInspectorApp extends StatelessWidget {
  const MemoryInspectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Memory Inspector',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      home: InspectorScreen(),
    );
  }
}