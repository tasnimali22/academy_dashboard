import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/feature/screens/exams/data/cubit/add_exam_cubit.dart';
import 'package:codingacademy_admin/feature/screens/exams/data/cubit/add_exam_state.dart';
import 'package:codingacademy_admin/feature/screens/exams/data/service/exams_service.dart';
import 'package:codingacademy_admin/feature/screens/exams/view/question_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddExamDialog extends StatelessWidget {
  const AddExamDialog({super.key, required this.courses});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> courses;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AddExamCubit(
        courseIds: courses.map((course) => course.id).toList(),
        service: ExamsService(),
      ),
      child: BlocConsumer<AddExamCubit, AddExamState>(
        listenWhen: (previous, current) => previous.saved != current.saved,
        listener: (context, state) {
          if (state.saved) Navigator.pop(context, true);
        },
        builder: (context, state) {
          final cubit = context.read<AddExamCubit>();
          return AlertDialog(
            title: const Text('إضافة امتحان'),
            content: SizedBox(
              width: 540,
              height: MediaQuery.sizeOf(context).height * 0.65,
              child: ListView(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'اسم الامتحان',
                    ),
                    onChanged: cubit.updateTitle,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: state.courseId,
                    decoration: const InputDecoration(labelText: 'الكورس'),
                    items: [
                      for (final course in courses)
                        DropdownMenuItem(
                          value: course.id,
                          child: Text(
                            course.data()['title'] as String? ?? course.id,
                          ),
                        ),
                    ],
                    onChanged: state.saving
                        ? null
                        : (value) {
                            if (value != null) cubit.selectCourse(value);
                          },
                  ),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'مدة الامتحان بالدقائق',
                    ),
                    onChanged: cubit.updateDuration,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: state.saving
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: state.date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (date != null && context.mounted) {
                              cubit.selectDate(date);
                            }
                          },
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      'الموعد: ${state.date.day}/${state.date.month}/${state.date.year}',
                    ),
                  ),
                  const Divider(height: 24),
                  for (var index = 0; index < state.questions.length; index++)
                    QuestionForm(
                      key: ValueKey(index),
                      number: index + 1,
                      draft: state.questions[index],
                      onChanged: (question) =>
                          cubit.updateQuestion(index, question),
                    ),
                  if (state.questions.length < 100)
                    TextButton.icon(
                      onPressed: state.saving ? null : cubit.addQuestion,
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة سؤال'),
                    ),
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        state.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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
                onPressed: state.saving ? null : cubit.save,
                child: state.saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ الامتحان'),
              ),
            ],
          );
        },
      ),
    );
  }
}
