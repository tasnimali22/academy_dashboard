import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/core/utils/confirm_dialog.dart';
import 'package:codingacademy_admin/feature/screens/exams/data/cubit/exams_cubit.dart';
import 'package:codingacademy_admin/feature/screens/exams/data/cubit/exams_state.dart';
import 'package:codingacademy_admin/feature/screens/exams/view/add_exam_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExamsPage extends StatelessWidget {
  const ExamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExamsCubit(),
      child: BlocConsumer<ExamsCubit, ExamsState>(
        listenWhen: (previous, current) =>
            previous.errorMessage != current.errorMessage ||
            previous.notification != current.notification,
        listener: (context, state) {
          final message = state.errorMessage ?? state.notification;
          if (message == null) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          context.read<ExamsCubit>().clearMessages();
        },
        builder: (context, state) {
          final cubit = context.read<ExamsCubit>();
          return Scaffold(
            appBar: AppBar(
              title: const Text('الامتحانات'),
              actions: [
                IconButton(
                  tooltip: 'تأمين إجابات الامتحانات القديمة',
                  onPressed: state.migrating
                      ? null
                      : () => _confirmMigration(context, cubit),
                  icon: state.migrating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.security),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('امتحان جديد'),
              onPressed: state.loading || state.courses.isEmpty
                  ? null
                  : () => _showAddExam(context, state.courses),
            ),
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, ExamsState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.exams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: context.read<ExamsCubit>().clearMessages,
                child: const Text('إغلاق'),
              ),
            ],
          ),
        ),
      );
    }
    if (state.exams.isEmpty) {
      return Center(
        child: Text(
          state.courses.isEmpty
              ? 'أضيفي كورسًا قبل إنشاء الامتحان'
              : 'لا توجد امتحانات، أضيفي أول امتحان',
          textAlign: TextAlign.center,
        ),
      );
    }

    final courseTitles = {
      for (final course in state.courses)
        course.id: course.data()['title'] as String? ?? course.id,
    };

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: state.exams.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final exam = state.exams[index];
        final data = exam.data();
        final date = data['date'];
        final examDate = date is Timestamp ? date.toDate() : null;
        final dateLabel = examDate == null
            ? 'بدون موعد'
            : '${examDate.day}/${examDate.month}/${examDate.year}';
        final courseId = data['courseId'] as String? ?? '';
        return Card(
          child: ListTile(
            leading: const Icon(Icons.quiz_outlined, size: 32),
            title: Text((data['title'] as String?) ?? exam.id),
            subtitle: Text(
              '${courseTitles[courseId] ?? courseId} • '
              '${data['questionsCount'] ?? 0} أسئلة • $dateLabel',
            ),
            trailing: IconButton(
              tooltip: 'حذف الامتحان',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context, exam.reference),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddExam(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> courses,
  ) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => AddExamDialog(courses: courses),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> examReference,
  ) async {
    final confirmed = await confirmDelete(
      context,
      'سيتم حذف الامتحان وكل أسئلته وإجاباته. هل تريدين المتابعة؟',
    );
    if (!confirmed || !context.mounted) return;
    await context.read<ExamsCubit>().deleteExam(examReference);
  }

  Future<void> _confirmMigration(BuildContext context, ExamsCubit cubit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأمين الامتحانات القديمة'),
        content: const Text(
          'سيتم نقل الإجابات الصحيحة إلى مساحة خاصة بالإدارة وحذفها من '
          'الأسئلة. يمكنك إعادة المحاولة إذا انقطع الاتصال.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأمين الآن'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await cubit.migrateLegacyAnswers();
    }
  }
}
