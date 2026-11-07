class ExamQuestionDraft {
  const ExamQuestionDraft({
    this.text = '',
    this.options = const ['', '', '', ''],
    this.correctIndex = 0,
  });

  final String text;
  final List<String> options;
  final int correctIndex;

  ExamQuestionDraft copyWith({
    String? text,
    List<String>? options,
    int? correctIndex,
  }) {
    return ExamQuestionDraft(
      text: text ?? this.text,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
    );
  }

  Map<String, dynamic> toFirestore(int order) => {
    'text': text.trim(),
    'options': options.map((option) => option.trim()).toList(),
    'order': order,
  };
}
