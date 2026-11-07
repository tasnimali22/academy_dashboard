

import 'package:codingacademy_admin/feature/screens/courses/data/model/courses_model.dart';

class CoursesState {
  final bool loading;
  final List<CourseModel> courses;
  final String? message; 
  const CoursesState({
    this.loading = true,
    this.courses = const [],
    this.message,
  });
}