import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:ffi/ffi.dart';

// --- DATA MODELS ---

class MemoryRegion {
  final int base;
  final int size;
  final int state;
  final int protect;
  final int type;

  MemoryRegion({
    required this.base,
    required this.size,
    required this.state,
    required this.protect,
    required this.type,
  });

  bool get isCommitted => state == 0x1000;

  bool get isReadable {
    if (!isCommitted || (protect & 0x100) != 0 || (protect & 0x01) != 0) return false;
    const readFlags = 0x02 | 0x04 | 0x20 | 0x40;
    return (protect & readFlags) != 0;
  }
}

class MemoryView {
  final ByteData data;
  final int actualLength;
  MemoryView(this.data, this.actualLength);

  bool canRead(int offset, int size) => (offset + size) <= actualLength;
  Uint8List get bytes => data.buffer.asUint8List(0, actualLength);
  
  int? getUint64(int offset) => canRead(offset, 8) ? data.getUint64(offset, Endian.little) : null;
}

class InspectNode {
  final int address;
  final String type;
  final dynamic value;
  final bool isExpandable; 
  final Uint8List? rawBytes;
  final List<InspectNode> children;

  InspectNode({
    required this.address,
    required this.type,
    this.value,
    this.isExpandable = false,
    this.children = const [],
    this.rawBytes,
    
  });

  Map<String, dynamic> toJson() {
    return {
      'address': '0x${address.toRadixString(16).toUpperCase()}',
      'type': type,
      'value': value?.toString() ?? 'N/A',
      'isExpandable': isExpandable,
      'raw': rawBytes != null ? base64Encode(rawBytes!) : "",
      'children': children.map((c) => c.toJson()).toList(),
    };
  }
  String toJsonString() {
    return jsonEncode(toJson());
  }
}

// --- WIN32 FFI ---

final class MEMORY_BASIC_INFORMATION extends Struct {
  @UintPtr() external int BaseAddress;
  @UintPtr() external int AllocationBase;
  @Uint32() external int AllocationProtect;
  @UintPtr() external int RegionSize;
  @Uint32() external int State;
  @Uint32() external int Protect;
  @Uint32() external int Type;
}


class MemoryService {
  final _kernel32 = DynamicLibrary.open("kernel32.dll");

  late final _virtualQuery = _kernel32.lookupFunction<
      IntPtr Function(Pointer<Void>, Pointer<Void>, IntPtr),
      int Function(Pointer<Void>, Pointer<Void>, int)>('VirtualQuery');

  late final _readProcessMemory = _kernel32.lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Void>, Pointer<Void>, IntPtr, Pointer<Void>),
      int Function(Pointer<Void>, Pointer<Void>, Pointer<Void>, int, Pointer<Void>)>('ReadProcessMemory');

  List<MemoryRegion> getRegions({int maxRegions = 1000}) {
    final regions = <MemoryRegion>[];
    final mbi = calloc<MEMORY_BASIC_INFORMATION>();
    int address = 0;

    while (regions.length < maxRegions) {
      final res = _virtualQuery(Pointer.fromAddress(address).cast(), mbi.cast(), sizeOf<MEMORY_BASIC_INFORMATION>());
      if (res == 0) break;
      regions.add(MemoryRegion(
        base: mbi.ref.BaseAddress,
        size: mbi.ref.RegionSize,
        state: mbi.ref.State,
        protect: mbi.ref.Protect,
        type: mbi.ref.Type,
      ));
      address = mbi.ref.BaseAddress + mbi.ref.RegionSize;
      if (address == 0 || address >= 0x7FFFFFFFFFFF) break;
    }
    calloc.free(mbi);
    return regions;
  }

  Uint8List? read(int address, int size) {
    if (size <= 0) return null;
    final buffer = calloc<Uint8>(size);
    final lpBytesRead = calloc<IntPtr>();
    final success = _readProcessMemory(Pointer.fromAddress(-1).cast(), Pointer.fromAddress(address).cast(), buffer.cast(), size, lpBytesRead.cast());
    
    final actualCount = lpBytesRead.value;
    Uint8List? result = (success != 0 || actualCount > 0) ? Uint8List.fromList(buffer.asTypedList(actualCount)) : null;

    calloc.free(buffer);
    calloc.free(lpBytesRead);
    return result;
  }


bool _isSmi(int v) => (v & 1) == 0;
int _decodeSmi(int v) => v >> 1;

// NEW: Explicitly identify tagged heap pointers
bool _isTaggedPointer(int v) => (v & 1) == 1;
bool _looksLikePointer(int addr) {
  return addr >= 0x10000 && addr <= 0x7FFFFFFFFFFF && (addr& 0x7== 0);
}
bool _isAddressInMap(int addr, List<MemoryRegion> regions) {
    return regions.any((r) => addr >= r.base && addr < (r.base + r.size));
  }
InspectNode inspect(int address, List<MemoryRegion> regions) {
  final raw = read(address, 64);
  if (raw == null) return InspectNode(address: address, type: "Error", value: "Access Denied");

  final view = MemoryView(raw.buffer.asByteData(), raw.length);
  final children = <InspectNode>[];
  final scanLimit = min(32, view.actualLength - 7);

  for (int i = 0; i < scanLimit; i += 8) {
    final val = view.getUint64(i);
    if (val == null) continue;

    // 1. SMI Check (Direct value)
    if (_isSmi(val) && val != 0) {
      children.add(InspectNode(
        address: address + i, 
        type: "SMI", 
        value: _decodeSmi(val)
      ));
      continue;
    }

    // 2. Tagged Pointer Check (The "Untag-then-Validate" Flow)
    if (_isTaggedPointer(val)) {
      final realAddr = val - 1; // Subtract the tag bit

      if (_looksLikePointer(realAddr)) {
        final mapped = _isAddressInMap(realAddr, regions);
        children.add(InspectNode(
          address: realAddr,
          // "Likely" means it's tagged AND in our known memory map
          // "Weak" means it's tagged but pointing to an unmapped/mystery region
          type: mapped ? "HeapObject (likely)" : "HeapObject (weak)",
          value: "Offset +$i",
          isExpandable: true,
        ));
      }
      continue;
    }

    // 3. Fallback: Raw/Untagged Pointer
    if (_looksLikePointer(val)) {
      children.add(InspectNode(
        address: val, 
        type: "Pointer (raw)", 
        value: "Offset +$i", 
        isExpandable: true
      ));
    }
  }

  return InspectNode(
    address: address,
    type: "Region",
    value: "Read ${view.actualLength} bytes",
    children: children,
    rawBytes: raw,
  );
}}

// --- VM SERVICE BRIDGE------

