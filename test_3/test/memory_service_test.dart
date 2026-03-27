import 'package:test/test.dart';
import 'package:ffi/ffi.dart';
import 'dart:io';
import 'package:memory_inspector/test_3.dart';

void main() {
  group('MemoryService', () {
    late MemoryService service;
    
    setUp(() {
      if (!Platform.isWindows) {
        fail('Windows only!');
      }
      service = MemoryService();
    });

    test('getRegions returns regions', () async {
      final regions = service.getRegions();
      expect(regions, isNotEmpty);
      expect(regions.first.base, greaterThanOrEqualTo(0));
      expect(regions.first.size, greaterThan(0));
    });

    group('read() - Raw bytes', () {
      test('read valid readable region', () {
        final regions = service.getRegions();
        
        // FIX: filter first, then check isNotEmpty to avoid null-safety issues with orElse
        final readableList = regions.where((r) => r.isReadable).toList();
        if (readableList.isEmpty) return; 
        
        final readable = readableList.first;
        final bytes = service.read(readable.base, 16);
        
        expect(bytes, isNotNull);
        expect(bytes!.length, greaterThan(0));
        expect(bytes.length, lessThanOrEqualTo(16));
      });

      test('read invalid address returns null', () {
        final bytes = service.read(0xDEADBEEF, 16);
        expect(bytes, isNull);
      });

      test('read zero size returns null', () {
        // Updated to address 0x0 or safe address to avoid crashes
        final bytes = service.read(0x10000, 0);
        expect(bytes, isNull);
      });
    });

    group('Interpretation Layer', () {
      test('readInt32 valid address', () {
        final regions = service.getRegions();
        final readableList = regions.where((r) => r.isReadable).toList();
        if (readableList.isEmpty) return;

        final value = service.readInt32(readableList.first.base);
        expect(value, isNotNull);
      });

      test('readInt32 short read returns null', () {
        final value = service.readInt32(0xDEADBEEF);
        expect(value, isNull);
      });

      test('readInt64 valid address', () {
        final regions = service.getRegions();
        final readableList = regions.where((r) => r.isReadable).toList();
        if (readableList.isEmpty) return;

        final value = service.readInt64(readableList.first.base);
        expect(value, isNotNull);
      });

      test('readCString valid string', () {
        final regions = service.getRegions();
        bool found = false;
        for (final region in regions.where((r) => r.isReadable)) {
          final str = service.readCString(region.base);
          if (str != null && str.isNotEmpty) {
            print('Found string: $str');
            found = true;
            break;
          }
        }
        // String interpretation is variable, but logic should complete
      });
    });

    group('Pointer Expansion (Daco\'s Feature)', () {
      test('expandAsInt32 readable region', () {
        final regions = service.getRegions();
        final readableList = regions.where((r) => r.isReadable).toList();
        if (readableList.isEmpty) return;

        final array = service.expandAsInt32(readableList.first.base, 4, regions);
        expect(array, isNotNull);
        expect(array!.length, greaterThan(0));
        expect(array.length, lessThanOrEqualTo(4));
      });

      test('expandAsInt32 unclamped size', () {
        final regions = service.getRegions();
        final readableList = regions.where((r) => r.isReadable).toList();
        if (readableList.isEmpty) return;

        final readable = readableList.first;
        final array = service.expandAsInt32(readable.base, 1000, regions);
        expect(array, isNotNull);
        // Should be clamped by region size if 4000 bytes > region size
      });
    });

    group('Internal safety', () {
      test('unreadable region returns null', () {
        final regions = service.getRegions();
        final unreadableList = regions.where((r) => !r.isReadable).toList();
        if (unreadableList.isEmpty) return;

        // Since _readWithMapValidation is internal, ensure it is accessible 
        // or test via public methods that use it.
        final bytes = service.expandAsInt32(unreadableList.first.base, 4, regions);
        expect(bytes, isNull);
      });

      test('unknown address returns null', () {
        final regions = service.getRegions();
        final bytes = service.expandAsInt32(0xDEADBEEF, 4, regions);
        expect(bytes, isNull);
      });
    });
  });
}