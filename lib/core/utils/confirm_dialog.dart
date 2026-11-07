import 'package:codingacademy_admin/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

Future<bool> confirmDelete(BuildContext context, String text) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('تأكيد الحذف'),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('حذف', style: AppTextStyles.destructiveAction),
        ),
      ],
    ),
  );
  return ok == true;
}