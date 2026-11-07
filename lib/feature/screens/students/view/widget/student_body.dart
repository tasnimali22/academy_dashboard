import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/feature/screens/students/data/cubit/students_cubit.dart';
import 'package:codingacademy_admin/feature/screens/students/data/cubit/students_state.dart';
import 'package:codingacademy_admin/feature/screens/students/view/students_page.dart';
import 'package:codingacademy_admin/feature/screens/students/view/widget/create_student_account_dialog.dart';
import 'package:codingacademy_admin/feature/screens/students/view/widget/student_permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StudentsBody extends StatelessWidget {
  const StudentsBody({super.key, required this.state});

  final StudentsState state;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: context.read<StudentsCubit>().refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final students = state.students;
    final studentIds = students.map((student) => student.id).toSet();
    final adminsWithoutProfiles =
        state.adminIds
            .where((adminId) => !studentIds.contains(adminId))
            .toList()
          ..sort();
    if (students.isEmpty && adminsWithoutProfiles.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد ملفات طلاب أو أدمن بعد. على المستخدم تسجيل الدخول إلى '
            'التطبيق مرة واحدة لإنشاء ملفه.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (students.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text('الحسابات'),
          ),
          for (final student in students) ...[
            _studentTile(context, student, state),
            const SizedBox(height: 8),
          ],
        ],
        if (adminsWithoutProfiles.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text('الأدمن'),
          ),
          for (final adminId in adminsWithoutProfiles) ...[
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.admin_panel_settings_outlined),
                ),
                title: Text(adminId),
                subtitle: const Text('أدمن'),
                trailing: state.accountActionIds.contains(adminId)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : PopupMenuButton<String>(
                        tooltip: 'إدارة الحساب',
                        onSelected: (action) =>
                            _handleAccountAction(context, adminId, action),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'demote',
                            child: Text('إزالة صلاحية الأدمن'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('حذف الحساب'),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _studentTile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> student,
    StudentsState state,
  ) {
    final data = student.data();
    final name = (data['name'] as String?)?.trim();
    final email = (data['email'] as String?)?.trim() ?? '';
    final courseCount = stringList(data['courseIds']).length;
    final examCount = stringList(data['examIds']).length;
    final isAdmin = state.adminIds.contains(student.id);
    final isBusy = state.accountActionIds.contains(student.id);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            isAdmin
                ? Icons.admin_panel_settings_outlined
                : Icons.person_outline,
          ),
        ),
        title: Row(
          children: [
            Flexible(child: Text(studentName(student.id, name, email))),
            if (isAdmin) ...[
              const SizedBox(width: 8),
              const Chip(
                avatar: Icon(Icons.verified_user_outlined, size: 16),
                label: Text('أدمن'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
        subtitle: Text('$courseCount كورسات • $examCount امتحانات مسموحة'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              PopupMenuButton<String>(
                tooltip: 'إدارة الحساب',
                onSelected: (action) =>
                    _handleAccountAction(context, student.id, action),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: isAdmin ? 'demote' : 'promote',
                    child: Text(
                      isAdmin ? 'إزالة صلاحية الأدمن' : 'تعيين كأدمن',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('حذف الحساب'),
                  ),
                ],
              ),
            const Icon(Icons.chevron_left),
          ],
        ),
        onTap: () => _openPermissions(context, student, state),
      ),
    );
  }

  static Future<void> showCreateStudentDialog(BuildContext context) async {
    final details = await showDialog<(String, String, String)>(
      context: context,
      builder: (_) => const CreateStudentAccountDialog(),
    );
    if (details != null && context.mounted) {
      await context.read<StudentsCubit>().createStudentAccount(
        name: details.$1,
        email: details.$2,
        password: details.$3,
      );
    }
  }

  Future<void> _handleAccountAction(
    BuildContext context,
    String studentId,
    String action,
  ) async {
    if (action == 'promote') {
      final confirmed = await _confirm(
        context,
        title: 'تعيين أدمن',
        message:
            'سيحصل هذا الحساب على صلاحيات إدارة الطلاب والكورسات والامتحانات. هل تريدين المتابعة؟',
        confirmLabel: 'تعيين كأدمن',
      );
      if (confirmed && context.mounted) {
        await context.read<StudentsCubit>().setAdminRole(
          studentId,
          isAdmin: true,
        );
      }
      return;
    }
    if (action == 'demote') {
      final confirmed = await _confirm(
        context,
        title: 'إزالة صلاحية الأدمن',
        message: 'سيعود هذا الحساب إلى حساب طالب عادي. هل تريدين المتابعة؟',
        confirmLabel: 'إزالة الصلاحية',
      );
      if (confirmed && context.mounted) {
        await context.read<StudentsCubit>().setAdminRole(
          studentId,
          isAdmin: false,
        );
      }
      return;
    }
    if (action == 'delete') {
      final confirmed = await _confirm(
        context,
        title: 'حذف الحساب نهائيًا',
        message:
            'سيتم حذف حساب تسجيل الدخول وملف الطالب وبياناته التابعة. لا يمكن التراجع عن هذا الإجراء.',
        confirmLabel: 'حذف نهائي',
      );
      if (confirmed && context.mounted) {
        await context.read<StudentsCubit>().deleteAccount(studentId);
      }
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: title.startsWith('حذف')
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _openPermissions(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> student,
    StudentsState state,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => StudentPermissionsDialog(
        student: student,
        courses: state.courses,
        exams: state.exams,
      ),
    );
  }
}
