import 'package:equatable/equatable.dart';

class StudentPermissionsState extends Equatable {
  const StudentPermissionsState({
    this.courseIds = const {},
    this.examIds = const {},
    this.saving = false,
    this.saved = false,
    this.errorMessage,
  });

  final Set<String> courseIds;
  final Set<String> examIds;
  final bool saving;
  final bool saved;
  final String? errorMessage;

  StudentPermissionsState copyWith({
    Set<String>? courseIds,
    Set<String>? examIds,
    bool? saving,
    bool? saved,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StudentPermissionsState(
      courseIds: courseIds ?? this.courseIds,
      examIds: examIds ?? this.examIds,
      saving: saving ?? this.saving,
      saved: saved ?? this.saved,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [courseIds, examIds, saving, saved, errorMessage];
}
