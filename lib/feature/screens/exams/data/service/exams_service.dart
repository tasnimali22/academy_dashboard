import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/feature/screens/exams/data/model/exam_question_draft.dart';

class ExamAnswerMigrationResult {
  const ExamAnswerMigrationResult({
    required this.migratedQuestions,
    required this.unresolvedQuestions,
  });

  final int migratedQuestions;
  final List<String> unresolvedQuestions;
}

class ExamsService {
  ExamsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchExams() =>
      _firestore.collection('exams').orderBy('order').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCourses() =>
      _firestore.collection('courses').orderBy('order').snapshots();

  Future<void> createExam({
    required String title,
    required String courseId,
    required int durationMinutes,
    required DateTime date,
    required List<ExamQuestionDraft> questions,
  }) async {
    final exams = await _firestore.collection('exams').get();
    final maxOrder = exams.docs.fold<int>(0, (currentMax, exam) {
      final order = exam.data()['order'];
      return order is int && order > currentMax ? order : currentMax;
    });

    final examReference = _firestore.collection('exams').doc();
    final batch = _firestore.batch()
      ..set(examReference, {
        'title': title.trim(),
        'courseId': courseId,
        'questionsCount': questions.length,
        'durationMinutes': durationMinutes,
        'date': Timestamp.fromDate(date),
        'icon': 'code',
        'order': maxOrder + 1,
        'createdAt': FieldValue.serverTimestamp(),
      });

    for (var index = 0; index < questions.length; index++) {
      final questionReference = examReference.collection('questions').doc();
      batch
        ..set(questionReference, questions[index].toFirestore(index + 1))
        ..set(
          examReference.collection('answerKeys').doc(questionReference.id),
          {'correctIndex': questions[index].correctIndex},
        );
    }

    await batch.commit();
  }

  Future<void> deleteExam(
    DocumentReference<Map<String, dynamic>> examReference,
  ) async {
    final questions = await examReference.collection('questions').get();
    final answerKeys = await examReference.collection('answerKeys').get();
    final documents = [...questions.docs, ...answerKeys.docs];

    for (var start = 0; start < documents.length; start += 400) {
      final batch = _firestore.batch();
      for (final document in documents.skip(start).take(400)) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
    await examReference.delete();
  }

  Future<ExamAnswerMigrationResult> migrateLegacyAnswers() async {
    final exams = await _firestore.collection('exams').get();
    var migratedQuestions = 0;
    final unresolvedQuestions = <String>[];

    for (final exam in exams.docs) {
      final questions = await exam.reference.collection('questions').get();
      final legacyQuestions = questions.docs.where((question) {
        return question.data().containsKey('correctIndex');
      }).toList();

      for (var start = 0; start < legacyQuestions.length; start += 200) {
        final chunk = legacyQuestions.skip(start).take(200).toList();
        final answerKeyReferences = chunk
            .map(
              (question) =>
                  exam.reference.collection('answerKeys').doc(question.id),
            )
            .toList();
        final existingAnswerKeys = await Future.wait(
          answerKeyReferences.map((reference) => reference.get()),
        );
        final batch = _firestore.batch();
        var migratedInBatch = 0;

        for (var index = 0; index < chunk.length; index++) {
          final question = chunk[index];
          final data = question.data();
          final options = data['options'];
          final correctIndex = _parseCorrectIndex(
            data['correctIndex'],
            options,
          );
          final existingCorrectIndex = _parseCorrectIndex(
            existingAnswerKeys[index].data()?['correctIndex'],
            options,
          );
          final resolvedIndex = correctIndex ?? existingCorrectIndex;
          if (resolvedIndex == null) {
            unresolvedQuestions.add(
              '${exam.id}/${question.id}: ${_invalidAnswerReason(data)}',
            );
            continue;
          }

          final publicQuestion = Map<String, dynamic>.from(data)
            ..remove('correctIndex');
          batch
            ..set(answerKeyReferences[index], {'correctIndex': resolvedIndex})
            ..set(question.reference, publicQuestion);
          migratedInBatch++;
        }

        if (migratedInBatch > 0) {
          await batch.commit();
          migratedQuestions += migratedInBatch;
        }
      }
    }
    return ExamAnswerMigrationResult(
      migratedQuestions: migratedQuestions,
      unresolvedQuestions: unresolvedQuestions,
    );
  }

  int? _parseCorrectIndex(dynamic value, dynamic rawOptions) {
    if (rawOptions is! List ||
        rawOptions.length < 2 ||
        rawOptions.any((option) => option is! String)) {
      return null;
    }

    final options = rawOptions.cast<String>();
    int? index;
    if (value is int) {
      index = value;
    } else if (value is num && value == value.roundToDouble()) {
      index = value.toInt();
    } else if (value is String) {
      index = int.tryParse(value.trim());
      if (index == null) {
        final matches = [
          for (var optionIndex = 0; optionIndex < options.length; optionIndex++)
            if (options[optionIndex].trim() == value.trim()) optionIndex,
        ];
        if (matches.length == 1) index = matches.single;
      }
    }

    return index != null && index >= 0 && index < options.length ? index : null;
  }

  String _invalidAnswerReason(Map<String, dynamic> data) {
    final options = data['options'];
    if (options is! List ||
        options.length < 2 ||
        options.any((option) => option is! String)) {
      return 'الاختيارات مفقودة أو غير صالحة';
    }
    return 'الإجابة "${data['correctIndex']}" لا تطابق رقم اختيار صالحًا '
        '(من 0 إلى ${options.length - 1})';
  }
}
