#!/usr/bin/env dart
// Simulates DevTools "Expand Pointer" UI

import 'dart:io';
import 'package:memory_inspector/test_3.dart';

void main() {
  if (!Platform.isWindows) {
    print("❌ This demo requires Windows.");
    return;
  }

  final service = MemoryService();
  final regions = service.getRegions();
  
  print("🖥️  DevTools Memory Inspector Demo\n");
  
  // FIX: firstWhere orElse must return a MemoryRegion. 
  // Using cast and checking for empty list is safer for null-safety.
  final readableRegions = regions.where((r) => r.isReadable).toList();

  if (readableRegions.isNotEmpty) {
    // Pick a safe region (above null pointer space)
    final readable = readableRegions.firstWhere(
      (r) => r.base > 0x10000, 
      orElse: () => readableRegions.first
    );

    print("Pointer: 0x${readable.base.toRadixString(16).toUpperCase()}");
    print("Expanded as Int32[16]:");
    
    // Using the expansion feature Daco requested
    final array = service.expandAsInt32(readable.base, 16, regions);
    
    if (array != null) {
      for (int i = 0; i < array.length; i++) {
        print("  [$i] = ${array[i]}");
      }
    } else {
      print("  Unable to read memory at this address.");
    }
  } else {
    print("⚠️ No readable memory regions found.");
  }

  print("\n✅ Demo Complete.");
}