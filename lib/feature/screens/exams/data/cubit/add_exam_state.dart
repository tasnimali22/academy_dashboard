import 'package:codingacademy_admin/feature/screens/exams/data/model/exam_question_draft.dart';
import 'package:equatable/equatable.dart';

class AddExamState extends Equatable {
  const AddExamState({
    required this.courseId,
    required this.date,
    this.title = '',
    this.durationMinutes = '30',
    this.questions = const [ExamQuestionDraft()],
    this.saving = false,
    this.saved = false,
    this.errorMessage,
  });

  final String courseId;
  final DateTime date;
  final String title;
  final String durationMinutes;
  final List<ExamQuestionDraft> questions;
  final bool saving;
  final bool saved;
  final String? errorMessage;

  AddExamState copyWith({
    String? courseId,
    DateTime? date,
    String? title,
    String? durationMinutes,
    List<ExamQuestionDraft>? questions,
    bool? saving,
    bool? saved,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AddExamState(
      courseId: courseId ?? this.courseId,
      date: date ?? this.date,
      title: title ?? this.title,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      questions: questions ?? this.questions,
      saving: saving ?? this.saving,
      saved: saved ?? this.saved,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    courseId,
    date,
    title,
    durationMinutes,
    questions,
    saving,
    saved,
    errorMessage,
  ];
}
