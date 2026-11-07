import 'package:codingacademy_admin/feature/screens/lesson/data/model.dart';

class LessonsState {
  final bool loading;
  final List<LessonMOdel> lessons;
  final String? message;
  const LessonsState({
    this.loading = true,
    this.lessons = const [],
    this.message,
  });
}
