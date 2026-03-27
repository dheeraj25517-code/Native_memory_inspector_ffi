import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// --- DATA MODELS ---

class MemoryRegion {
  final int base;
  final int size;
  final int state;
  final int protect;

  MemoryRegion(this.base, this.size, this.state, this.protect);

  bool get isCommitted => state == 0x1000;

  bool get isReadable {
    if (!isCommitted || (protect & 0x100) != 0 || (protect & 0x01) != 0) return false;
    const readFlags = 0x02 | 0x04 | 0x20 | 0x40;
    return (protect & readFlags) != 0;
  }
  
  @override
  String toString() => "0x${base.toRadixString(16)} (${size} bytes)";
}

final class MEMORY_BASIC_INFORMATION extends Struct {
  @UintPtr() external int BaseAddress;
  @UintPtr() external int AllocationBase;
  @Uint32() external int AllocationProtect;
  @UintPtr() external int RegionSize;
  @Uint32() external int State;
  @Uint32() external int Protect;
  @Uint32() external int Type;
}

// --- THE SERVICE ---

class MemoryService {
  final _kernel32 = DynamicLibrary.open("kernel32.dll");

  late final _virtualQuery = _kernel32.lookupFunction<
      IntPtr Function(Pointer<Void>, Pointer<Void>, IntPtr),
      int Function(Pointer<Void>, Pointer<Void>, int)>('VirtualQuery');

  late final _readProcessMemory = _kernel32.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Void>, Pointer<Void>, IntPtr, Pointer<Void>),
      int Function(Pointer<Void>, Pointer<Void>, Pointer<Void>, int, Pointer<Void>)>('ReadProcessMemory');

  /// FIXED: Added the loop logic to actually find regions
  List<MemoryRegion> getRegions() {
    final regions = <MemoryRegion>[];
    final mbi = calloc<MEMORY_BASIC_INFORMATION>();
    int address = 0;

    // Standard Windows x64 user-space limit
    while (address < 0x7FFFFFFFFFFF) {
      final res = _virtualQuery(
          Pointer.fromAddress(address).cast(), mbi.cast(), sizeOf<MEMORY_BASIC_INFORMATION>());
      if (res == 0) break;

      regions.add(MemoryRegion(
          mbi.ref.BaseAddress, mbi.ref.RegionSize, mbi.ref.State, mbi.ref.Protect));

      address = mbi.ref.BaseAddress + mbi.ref.RegionSize;
      if (address == 0) break; // End of address space
    }

    calloc.free(mbi);
    return regions;
  }

  Uint8List? read(int address, int size) {
    if (address == 0) return null;
    final buffer = calloc<Uint8>(size);
    final lpBytesRead = calloc<IntPtr>();

    _readProcessMemory(Pointer.fromAddress(-1).cast(), Pointer.fromAddress(address).cast(),
        buffer.cast(), size, lpBytesRead.cast());

    final actualCount = lpBytesRead.value;
    Uint8List? data;
    if (actualCount > 0) {
      data = Uint8List.fromList(buffer.asTypedList(actualCount));
    }

    calloc.free(buffer);
    calloc.free(lpBytesRead);
    return data;
  }

  int? readInt32(int address) {
    final bytes = read(address, 4);
    if (bytes == null || bytes.length < 4) return null;
    return bytes.buffer.asByteData().getInt32(0, Endian.host);
  }

  int? readInt64(int address) {
    final bytes = read(address, 8);
    if (bytes == null || bytes.length < 8) return null;
    return bytes.buffer.asByteData().getInt64(0, Endian.host);
  }

  String? readCString(int address, {int limit = 128}) {
    final bytes = read(address, limit);
    if (bytes == null) return null;
    final nullPos = bytes.indexOf(0);
    final actualStringBytes = nullPos == -1 ? bytes : bytes.sublist(0, nullPos);
    try {
      return utf8.decode(actualStringBytes);
    } catch (_) {
      return null;
    }
  }

  Int32List? expandAsInt32(int address, int count, List<MemoryRegion> map) {
    final byteCount = count * 4;
    final bytes = _readWithMapValidation(address, byteCount, map);
    return bytes?.buffer.asInt32List();
  }

  Uint8List? _readWithMapValidation(int address, int size, List<MemoryRegion> map) {
    try {
      final region = map.firstWhere((r) => address >= r.base && address < (r.base + r.size));
      if (!region.isReadable) return null;
      final remaining = (region.base + region.size) - address;
      return read(address, size > remaining ? remaining : size);
    } catch (_) {
      return null;
    }
  }
}

// --- VOID MAIN ---

void main() {
  if (!Platform.isWindows) {
    print("This demo only runs on Windows.");
    return;
  }

  final service = MemoryService();

  // 1. Test getRegions
  print("1. getRegions():");
  final regions = service.getRegions();
  print("   ${regions.length} regions found");

  // 2. Find a reliable readable region (skipping NULL page)
  final readable = regions.firstWhere((r) => r.isReadable && r.base > 0x10000);
  
  print("\n2. read() test:");
  print("   Target Region: $readable");
  final bytes = service.read(readable.base, 32);
  final hex = bytes?.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ') ?? 'null';
  print("   ${bytes?.length ?? 0}/32 bytes: $hex");

  // 3. Test interpretation
  print("\n3. Interpretation:");
  final int32 = service.readInt32(readable.base);
  final int64 = service.readInt64(readable.base);
  final cstr = service.readCString(readable.base);
  print("   int32: $int32");
  print("   int64: 0x${int64?.toRadixString(16)}");
  print("   cstr:  ${cstr ?? 'null'}");

  // 4. Test expansion
  print("\n4. expandAsInt32():");
  final array = service.expandAsInt32(readable.base, 8, regions);
  print("   Array: ${array?.join(', ') ?? 'null'}");
  
  print("\n✅ Manual Demo Completed Successfully.");
}