import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PermissionList extends StatelessWidget {
  const PermissionList({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.emptyMessage,
    required this.onChanged,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> items;
  final Set<String> selectedIds;
  final String emptyMessage;
  final void Function(String id, bool enabled)? onChanged;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(child: Text(emptyMessage));
    return ListView(
      children: [
        for (final item in items)
          CheckboxListTile(
            value: selectedIds.contains(item.id),
            title: Text((item.data()['title'] as String?) ?? item.id),
            subtitle: Text(item.id),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: onChanged == null
                ? null
                : (enabled) => onChanged!(item.id, enabled == true),
          ),
      ],
    );
  }
}
