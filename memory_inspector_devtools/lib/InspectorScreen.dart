import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:test_3/test_3.dart'; // Ensure this matches your backend package
import 'package:memory_inspector_devtools/NodeWidget.dart';

class InspectorScreen extends StatefulWidget {
  const InspectorScreen({super.key});

  @override
  State<InspectorScreen> createState() => _InspectorScreenState();
}

class _InspectorScreenState extends State<InspectorScreen> {
  final controller = TextEditingController(text: "0x0");
  Map<String, dynamic>? rootNode;
  bool _isLoading = false;

  // 1. Initial Search (Top Level) - Clears screen and sets a new Root
  Future<void> inspectAddress(String address) async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 150));

    try {
      final clean = address.trim().toLowerCase().replaceFirst('0x', '');
      if (clean.isEmpty) throw "Invalid Address";

      // Safe 64-bit parsing
      final int addr = BigInt.parse(clean, radix: 16).toInt();

      final service = MemoryService();
      final regions = service.getRegions();
      final node = service.inspect(addr, regions);

      setState(() {
        rootNode = node.toJson();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Inspect Error: $e");
    }
  }

  // 2. Recursive Expansion (Nested Level) - Attaches children to existing nodes
  Future<void> expandNode(Map<String, dynamic> node) async {
    // Optimization: Don't fetch if children already exist
    if (node['children'] != null && (node['children'] as List).isNotEmpty) return;

    setState(() => _isLoading = true);
    try {
      final String addrStr = node['address'].toString();
      final clean = addrStr.toLowerCase().replaceFirst('0x', '');
      final int addr = BigInt.parse(clean, radix: 16).toInt();

      final service = MemoryService();
      final regions = service.getRegions();
      final newNode = service.inspect(addr, regions).toJson();

      setState(() {
        // THE MAGIC: We update the specific node's children in the existing tree
        node['children'] = newNode['children'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Expansion Error: $e");
    }
  }

  // Helper for snackbar notifications
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dart Memory Inspector'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: rootNode == null
                ? const Center(child: Text("Generate or Enter a hex address to begin"))
                : Row(
              children: [
                // --- POINTER TREE VIEW ---
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: NodeWidget(
                      node: rootNode!,
                      onExpand: expandNode, // Now correctly calls recursive logic
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                // --- HEX GRID PREVIEW ---
                Expanded(
                  flex: 2,
                  child: _buildHexPreview(rootNode!['raw']),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: 'Target Address',
                    hintText: '0x7FF...',
                  ),
                  onSubmitted: (val) => inspectAddress(val),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.search),
                onPressed: () => inspectAddress(controller.text),
                label: const Text('Inspect'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.grid_view),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade900),
                  onPressed: () {
                    final ptr = calloc<Uint8>(64);
                    for (int i = 0; i < 64; i++) ptr[i] = (i % 2 == 0) ? 0xAA : 0xBB;
                    final addr = "0x${ptr.address.toRadixString(16).toUpperCase()}";
                    controller.text = addr;
                    inspectAddress(addr);
                  },
                  label: const Text("MAGIC BLOCK"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.account_tree_outlined),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade900),
                  onPressed: () {
                    final childPtr = calloc<Uint64>(1);
                    final parentPtr = calloc<Uint64>(1);
                    childPtr.value = 0xDEADC0DE;
                    parentPtr.value = childPtr.address;

                    final addr = "0x${parentPtr.address.toRadixString(16).toUpperCase()}";
                    controller.text = addr;
                    inspectAddress(addr);
                  },
                  label: const Text("POINTER CHAIN"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHexPreview(dynamic base64Raw) {
    if (base64Raw == null || base64Raw is! String || base64Raw.isEmpty) {
      return const Center(child: Text("No raw bytes available"));
    }
    final Uint8List bytes = base64Decode(base64Raw);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text("Raw Memory (64 Bytes)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 4, crossAxisSpacing: 4),
            itemCount: bytes.length,
            itemBuilder: (context, i) => Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), border: Border.all(color: Colors.white10)),
              child: Center(
                child: Text(bytes[i].toRadixString(16).padLeft(2, '0').toUpperCase(), style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ),
            ),
          ),
        ),
      ],
    );
  }
}