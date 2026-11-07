import 'package:codingacademy_admin/core/utils/confirm_dialog.dart';
import 'package:codingacademy_admin/feature/screens/lesson/data/cubit/lesson_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LessonsPage extends StatelessWidget {
  final String courseId;
  final String courseTitle;
  const LessonsPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LessonsCubit(courseId),
      child: BlocConsumer<LessonsCubit, LessonsState>(
        listener: (context, state) {
          if (state.message != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message!)));
          }
        },
        builder: (context, state) {
          final cubit = context.read<LessonsCubit>();

          return Scaffold(
            appBar: AppBar(title: Text(courseTitle)),
            floatingActionButton: FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('إضافة فيديو'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: const _AddLessonDialog(),
                ),
              ),
            ),
            body: _body(context, state, cubit),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, LessonsState state, LessonsCubit cubit) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.lessons.isEmpty) {
      return const Center(child: Text('مفيش فيديوهات في الكورس ده'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: state.lessons.length,
      itemBuilder: (context, i) {
        final l = state.lessons[i];
        return Card(
          child: ListTile(
            leading: SizedBox(
              width: 80,
              child: Image.network(
                'https://img.youtube.com/vi/${l.videoId}/hqdefault.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.play_circle_outline, size: 36),
              ),
            ),
            title: Text(l.title),
            subtitle: Text('الترتيب: ${l.order}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                final ok = await confirmDelete(
                    context, 'حذف الفيديو "${l.title}"؟');
                if (ok) cubit.deleteLesson(l.id);
              },
            ),
          ),
        );
      },
    );
  }
}

class _AddLessonDialog extends StatelessWidget {
  const _AddLessonDialog();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LessonsCubit>();

    return AlertDialog(
      title: const Text('إضافة فيديو'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: cubit.titleController,
            decoration: const InputDecoration(
              labelText: 'عنوان الفيديو',
              helperText: 'لو سبتيه فاضي هيتسمّى "الدرس 1" وهكذا',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cubit.linkController,
            decoration: const InputDecoration(
              labelText: 'رابط يوتيوب (Unlisted)',
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
            final ok = await cubit.addLesson();
            if (ok && context.mounted) Navigator.pop(context);
          },
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}