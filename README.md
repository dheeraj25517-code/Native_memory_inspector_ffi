# Native_memory_inspector_ffi
This is a working prototype of memory inspector for windows

A low-level memory inspection tool for Dart/Flutter that enables developers to read, visualize, and explore raw memory using platform-native APIs.

Features

Memory Inspection
* Inspect arbitrary memory addresses (`0x...`)
* Safe parsing with error handling
* Partial-read recovery support

Pointer Tree Exploration
* Recursive pointer traversal
* Expandable nodes (lazy exploration)
* Cycle-safe navigation

Dart Object Decoding
* SMI (Small Integer) decoding
* Basic heap object identification
* Pointer classification (heap vs raw)

Raw Memory Visualization
* 64-byte hex grid preview
* Base64 → byte decoding
* Structured layout for readability

Architecture (Current Prototype)

```
Flutter UI
   ↓
InspectorScreen (input + tree + hex)
   ↓
MemoryService (Dart logic)
   ↓
FFI Layer
   ↓
Windows Native APIs
   - VirtualQuery
   - ReadProcessMemory
```

---

Demo Workflow
1. Run the Windows app
2. Generate test memory:
   * Linked list (pointer chain)
   * Magic hex block
3. Copy the memory address
4. Paste into inspector UI
5. Explore:
   * Pointer tree
   * Raw hex view
   * Decoded values
---
## 📁 Project Structure

```
lib/
├── InspectorScreen.dart     # Main UI (tree + hex view)
├── memory_service.dart      # Core inspection logic
├── inspect_node.dart        # Data model
├── ffi/
│   ├── windows_reader.dart  # VirtualQuery + RPM
│   └── structs.dart         # Native bindings
```

---

Platform Support==Windows only

Limitations
* Not connected to DevTools yet (standalone UI)
* No GC synchronization (reads may be stale)
* Limited Dart object decoding
* Platform-specific implementation (Windows only for now)

Technical Highlights
* Hybrid model:
  * `VirtualQuery` → region awareness
  * `ReadProcessMemory` → ground truth
* Page-safe reads
* Expand-on-demand pointer traversal
* Defensive parsing for unsafe memory

Getting Started
### Prerequisites
* Flutter (Windows enabled)
* Visual Studio (C++ build tools)
### Run
```bash
flutter clean
flutter pub get
flutter run -d windows
```


Author-Dheeraj Kumar Thota
* Systems + Dart FFI Developer
* GSoC 2026 Applicant (Dart/Flutter)

Note:
This is a **prototype / research project** demonstrating feasibility of a **DevTools Memory Inspector extension**.
