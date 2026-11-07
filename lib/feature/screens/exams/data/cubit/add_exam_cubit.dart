import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/feature/screens/exams/data/cubit/add_exam_state.dart';
import 'package:codingacademy_admin/feature/screens/exams/data/model/exam_question_draft.dart';
import 'package:codingacademy_admin/feature/screens/exams/data/service/exams_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddExamCubit extends Cubit<AddExamState> {
  AddExamCubit({required List<String> courseIds, ExamsService? service})
    : _service = service ?? ExamsService(),
      super(
        AddExamState(
          courseId: courseIds.first,
          date: _dateOnly(DateTime.now()),
        ),
      );

  final ExamsService _service;

  void updateTitle(String value) =>
      emit(state.copyWith(title: value, clearError: true));

  void updateDuration(String value) =>
      emit(state.copyWith(durationMinutes: value, clearError: true));

  void selectCourse(String courseId) =>
      emit(state.copyWith(courseId: courseId, clearError: true));

  void selectDate(DateTime date) =>
      emit(state.copyWith(date: _dateOnly(date), clearError: true));

  void addQuestion() {
    if (state.questions.length >= 100) return;
    emit(
      state.copyWith(
        questions: [...state.questions, const ExamQuestionDraft()],
        clearError: true,
      ),
    );
  }

  void updateQuestion(int index, ExamQuestionDraft question) {
    if (index < 0 || index >= state.questions.length) return;
    final questions = [...state.questions];
    questions[index] = question;
    emit(state.copyWith(questions: questions, clearError: true));
  }

  Future<void> save() async {
    if (state.saving) return;
    final title = state.title.trim();
    final duration = int.tryParse(state.durationMinutes.trim());
    if (title.isEmpty || duration == null || duration < 1) {
      emit(
        state.copyWith(errorMessage: 'اكتبي اسم الامتحان ومدة صحيحة بالدقائق'),
      );
      return;
    }
    if (state.questions.any(
      (question) =>
          question.text.trim().isEmpty ||
          question.options.length != 4 ||
          question.options.any((option) => option.trim().isEmpty),
    )) {
      emit(state.copyWith(errorMessage: 'أكملي نص كل سؤال واختياراته الأربعة'));
      return;
    }

    emit(state.copyWith(saving: true, saved: false, clearError: true));
    try {
      await _service.createExam(
        title: title,
        courseId: state.courseId,
        durationMinutes: duration,
        date: state.date,
        questions: state.questions,
      );
      emit(state.copyWith(saving: false, saved: true));
    } on FirebaseException catch (error) {
      emit(
        state.copyWith(
          saving: false,
          errorMessage: 'تعذر إنشاء الامتحان: ${error.message}',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          saving: false,
          errorMessage: 'تعذر إنشاء الامتحان: $error',
        ),
      );
    }
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
