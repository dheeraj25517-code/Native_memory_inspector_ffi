#!/usr/bin/env dart
// Performance testing

// CHANGE: Fixed the import string. It had an extra ' at the end.
import 'package:memory_inspector/test_3.dart';
import 'dart:io';

void main() {
  if (!Platform.isWindows) {
    print("❌ This benchmark requires Windows.");
    return;
  }

  final service = MemoryService();
  
  // Initialize regions once to avoid cold-start bias
  final regions = service.getRegions();
  
  print("🚀 Starting benchmark (100 iterations)...");
  final sw = Stopwatch()..start();
  
  for (int i = 0; i < 100; i++) {
    service.getRegions();
  }
  
  sw.stop();
  
  print("\n📈 Performance Results:");
  print("   Found ${regions.length} regions.");
  print("   Total time for 100x scans: ${sw.elapsedMilliseconds}ms");
  print("   Average time per scan:     ${(sw.elapsedMilliseconds / 100).toStringAsFixed(2)}ms");
}