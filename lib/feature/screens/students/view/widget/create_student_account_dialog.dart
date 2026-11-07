import 'package:flutter/material.dart';

class CreateStudentAccountDialog extends StatefulWidget {
  const CreateStudentAccountDialog({super.key});

  @override
  State<CreateStudentAccountDialog> createState() =>
      _CreateStudentAccountDialogState();
}

class _CreateStudentAccountDialogState
    extends State<CreateStudentAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة حساب طالب'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'اسم الطالب'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'أدخلي اسم الطالب'
                    : null,
              ),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                ),
                validator: (value) => value == null || !value.contains('@')
                    ? 'أدخلي بريدًا إلكترونيًا صحيحًا'
                    : null,
              ),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور (6 أحرف على الأقل)',
                ),
                validator: (value) => value == null || value.length < 6
                    ? 'كلمة المرور يجب ألا تقل عن 6 أحرف'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('إنشاء الحساب')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    ));
  }
}
