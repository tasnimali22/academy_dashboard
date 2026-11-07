import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/core/theme/app_text_styles.dart';
import 'package:codingacademy_admin/feature/screens/students/data/cubit/student_permissions_cubit.dart';
import 'package:codingacademy_admin/feature/screens/students/data/cubit/student_permissions_state.dart';
import 'package:codingacademy_admin/feature/screens/students/view/students_page.dart';
import 'package:codingacademy_admin/feature/screens/students/view/widget/permission_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StudentPermissionsDialog extends StatelessWidget {
  const StudentPermissionsDialog({
    super.key,
    required this.student,
    required this.courses,
    required this.exams,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> student;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> courses;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> exams;

  @override
  Widget build(BuildContext context) {
    final data = student.data();
    final name = (data['name'] as String?)?.trim();
    final email = (data['email'] as String?)?.trim() ?? '';

    return DefaultTabController(
      length: 2,
      child: BlocProvider(
        create: (_) => StudentPermissionsCubit(
          student: student.reference,
          courseIds: stringList(data['courseIds']).toSet(),
          examIds: stringList(data['examIds']).toSet(),
        ),
        child: BlocConsumer<StudentPermissionsCubit, StudentPermissionsState>(
          listenWhen: (previous, current) => previous.saved != current.saved,
          listener: (context, state) {
            if (state.saved) Navigator.pop(context);
          },
          builder: (context, state) {
            return AlertDialog(
              title: Text(
                studentName(student.id, name, email),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              content: SizedBox(
                width: 480,
                height: 420,
                child: Column(
                  children: [
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          state.errorMessage!,
                          style: AppTextStyles.error(context),
                        ),
                      ),
                    const TabBar(
                      tabs: [
                        Tab(text: 'الكورسات'),
                        Tab(text: 'الامتحانات'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          PermissionList(
                            items: courses,
                            selectedIds: state.courseIds,
                            emptyMessage: 'أضيفي كورسات أولاً',
                            onChanged: state.saving
                                ? null
                                : context
                                      .read<StudentPermissionsCubit>()
                                      .toggleCourse,
                          ),
                          PermissionList(
                            items: exams,
                            selectedIds: state.examIds,
                            emptyMessage: 'أضيفي امتحانات أولاً',
                            onChanged: state.saving
                                ? null
                                : context
                                      .read<StudentPermissionsCubit>()
                                      .toggleExam,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: state.saving ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: state.saving
                      ? null
                      : context.read<StudentPermissionsCubit>().save,
                  child: state.saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('حفظ الصلاحيات'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
