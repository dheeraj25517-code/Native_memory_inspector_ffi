#!/usr/bin/env dart
// Entry point for MemoryService demo

import 'dart:io';
// Ensure 'memory_inspector' matches the 'name:' field in your pubspec.yaml
import 'package:memory_inspector/test_3.dart';

void main() {
  // Use a try-catch to handle potential FFI loading issues on non-Windows
  if (!Platform.isWindows) {
    print("❌ Error: This tool requires Windows APIs (kernel32.dll).");
    return;
  }

  final service = MemoryService();
  
  print("🔍 Native Memory Inspector v1.0");
  print("==============================\n");
  
  // 1. Memory map
  final regions = service.getRegions();
  // Filter for regions we can actually look at
  final readable = regions.where((r) => r.isReadable).toList();
  
  print("📊 Scanned: ${regions.length} total regions.");
  print("📊 Access:  ${readable.length} readable regions found.");
  
  // 2. First readable region demo (Safety check with firstOrNull logic)
  if (readable.isNotEmpty) {
    // Pick a region likely to have data (skipping the very low null-pointer memory)
    final region = readable.firstWhere((r) => r.base > 0x10000, orElse: () => readable.first);
    
    print("\n🎯 Target Region: $region");
    
    // 3. Raw bytes read
    // We use 64 bytes for a good hex dump preview
    final bytes = service.read(region.base, 64);
    if (bytes != null) {
      final hexString = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      print("📦 Raw Hex (first 64 bytes):");
      print("   $hexString");
    } else {
      print("📦 Bytes: null (Read failed)");
    }
    
    // 4. Typed interpretation (Phase 3 logic)
    final int64 = service.readInt64(region.base);
    final str = service.readCString(region.base);
    
    print("\n🔢 Interpretations at 0x${region.base.toRadixString(16).toUpperCase()}:");
    print("   As Int64:  ${int64 != null ? '0x${int64.toRadixString(16).toUpperCase()}' : 'null'}");
    print("   As C-Str:  \"${str ?? 'null'}\"");
    
    // 5. Array expansion (Daco's requested feature)
    // We try to expand the start of the region as a 32-bit integer array
    final array = service.expandAsInt32(region.base, 8, regions);
    if (array != null) {
      print("📈 Expanded Int32 Array (8 elements):");
      print("   [${array.join(', ')}]");
    } else {
      print("📈 Expanded Int32 Array: null");
    }
  } else {
    print("\n⚠️ No readable memory regions found. Run as Administrator if possible.");
  }
  
  print("\n✅ Demo finished. Ready for DevTools integration!");
}