import 'package:memory_inspector/test_3.dart';

void main() {
  final service = MemoryService();
  final regions = service.getRegions(maxRegions: 50);

  print('--- Memory Map Snapshot ---');
  for (var r in regions) {
    final status = r.isReadable ? '[READABLE]' : '[LOCKED]  ';
    print('$status Base: 0x${r.base.toRadixString(16).padLeft(12, "0")} | Size: ${r.size}');
  }
}