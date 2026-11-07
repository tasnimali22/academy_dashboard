import 'package:codingacademy_admin/core/utils/confirm_dialog.dart';
import 'package:codingacademy_admin/feature/screens/courses/data/cubit/courses_cubit.dart';
import 'package:codingacademy_admin/feature/screens/courses/data/cubit/courses_state.dart';
import 'package:codingacademy_admin/feature/screens/lesson/view/lesson_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CoursesPage extends StatelessWidget {
  const CoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CoursesCubit(),
      child: BlocConsumer<CoursesCubit, CoursesState>(
        listener: (context, state) {
          if (state.message != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message!)));
          }
        },
        builder: (context, state) {
          final cubit = context.read<CoursesCubit>();

          return Scaffold(
            appBar: AppBar(title: const Text('الكورسات')),
            floatingActionButton: FloatingActionButton.extended(
              icon: const Icon(Icons.create_new_folder),
              label: const Text('كورس جديد'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: const _AddCourseDialog(),
                ),
              ),
            ),
            body: _body(context, state, cubit),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, CoursesState state, CoursesCubit cubit) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.courses.isEmpty) {
      return const Center(child: Text('مفيش كورسات، أضيفي أول كورس'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: state.courses.length,
      itemBuilder: (context, i) {
        final c = state.courses[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.folder, size: 32),
            title: Text(c.title),
            subtitle: Text('الرمز: ${c.id}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                final ok = await confirmDelete(
                  context,
                  'سيتم حذف الكورس "${c.title}" وكل فيديوهاته. متأكدة؟',
                );
                if (ok) cubit.deleteCourse(c.id);
              },
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LessonsPage(courseId: c.id, courseTitle: c.title),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AddCourseDialog extends StatelessWidget {
  const _AddCourseDialog();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CoursesCubit>();

    return AlertDialog(
      title: const Text('كورس جديد'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: cubit.titleController,
            decoration: const InputDecoration(labelText: 'اسم الكورس'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cubit.idController,
            decoration: const InputDecoration(
              labelText: 'الرمز (إنجليزي) مثال: js',
              helperText: 'لازم يطابق رمز الكورس في تطبيق الطلاب',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            final ok = await cubit.addCourse();
            if (ok && context.mounted) Navigator.pop(context);
          },
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}