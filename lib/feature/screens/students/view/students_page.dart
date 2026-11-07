import 'package:codingacademy_admin/feature/screens/students/data/cubit/students_cubit.dart';
import 'package:codingacademy_admin/feature/screens/students/data/cubit/students_state.dart';
import 'package:codingacademy_admin/feature/screens/students/view/widget/student_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StudentsPage extends StatelessWidget {
  const StudentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StudentsCubit(),
      child: BlocConsumer<StudentsCubit, StudentsState>(
        listenWhen: (previous, current) =>
            previous.notification != current.notification,
        listener: (context, state) {
          final notification = state.notification;
          if (notification == null) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(notification)));
          context.read<StudentsCubit>().clearNotification();
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('الطلاب والصلاحيات'),
              actions: [
                if (state.isSuperAdmin)
                  IconButton(
                    tooltip: 'إضافة حساب طالب',
                    onPressed: state.creatingAccount
                        ? null
                        : () => StudentsBody.showCreateStudentDialog(context),
                    icon: state.creatingAccount
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1),
                  ),
                IconButton(
                  tooltip: 'تحديث قائمة الطلاب',
                  onPressed: state.refreshing
                      ? null
                      : context.read<StudentsCubit>().refresh,
                  icon: state.refreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                ),
              ],
            ),
            body: StudentsBody(state: state),
          );
        },
      ),
    );
  }
}

List<String> stringList(dynamic value) =>
    value is List ? value.whereType<String>().toList() : const [];

String studentName(String id, String? name, String email) {
  if (name != null && name.isNotEmpty && _isDisplayName(name)) return name;
  if (email.isNotEmpty) return email;
  return id;
}

bool _isDisplayName(String value) {
  final normalized = value.toLowerCase();
  return !normalized.contains('fieldpaths=') &&
      !normalized.contains('updatemask.') &&
      !normalized.contains('mustchangepassword');
}
