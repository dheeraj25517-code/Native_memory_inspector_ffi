import 'package:flutter/material.dart';

class NodeWidget extends StatelessWidget {
  final Map<String, dynamic> node;
  final Function(Map<String, dynamic> node) onExpand; // Changed from String to Map

  const NodeWidget({super.key, required this.node, required this.onExpand});

  @override
  Widget build(BuildContext context) {
    final address = node['address']?.toString() ?? '0x0';
    final type = node['type']?.toString() ?? 'Unknown';
    final value = node['value']?.toString() ?? 'N/A';
    final children = node['children'] as List? ?? [];
    final bool isExpandable = node['isExpandable'] == true;

    // Check if we already fetched data for this node
    final bool hasData = children.isNotEmpty;

    return ExpansionTile(
      key: PageStorageKey(address),
      // Trigger expansion fetch when the tile is opened
      onExpansionChanged: (expanded) {
        if (expanded && isExpandable && !hasData) {
          onExpand(node);
        }
      },
      leading: Icon(
        type.contains('Heap') ? Icons.layers : Icons.memory,
        color: type.contains('Heap') ? Colors.greenAccent : Colors.blueAccent,
        size: 18,
      ),
      title: Text(address, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
      subtitle: Text("$type | Value: $value", style: const TextStyle(fontSize: 11)),
      children: children.map((c) => Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: NodeWidget(node: c as Map<String, dynamic>, onExpand: onExpand),
      )).toList(),
    );
  }
}