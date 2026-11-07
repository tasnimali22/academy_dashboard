import 'package:codingacademy_admin/feature/screens/exams/data/model/exam_question_draft.dart';
import 'package:flutter/material.dart';

class QuestionForm extends StatefulWidget {
  const QuestionForm({
    super.key,
    required this.number,
    required this.draft,
    required this.onChanged,
  });

  final int number;
  final ExamQuestionDraft draft;
  final ValueChanged<ExamQuestionDraft> onChanged;

  @override
  State<QuestionForm> createState() => _QuestionFormState();
}

class _QuestionFormState extends State<QuestionForm> {
  late final TextEditingController _textController;
  late final List<TextEditingController> _optionControllers;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.draft.text);
    _optionControllers = widget.draft.options
        .map((text) => TextEditingController(text: text))
        .toList();
  }

  @override
  void didUpdateWidget(covariant QuestionForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.text != widget.draft.text &&
        widget.draft.text != _textController.text) {
      _textController.value = TextEditingValue(
        text: widget.draft.text,
        selection: TextSelection.collapsed(offset: widget.draft.text.length),
      );
    }
    for (var index = 0; index < _optionControllers.length; index++) {
      final value = widget.draft.options[index];
      if (oldWidget.draft.options[index] != value &&
          _optionControllers[index].text != value) {
        _optionControllers[index].value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _emitDraft({
    String? text,
    int? correctIndex,
    int? changedOptionIndex,
    String? optionValue,
  }) {
    final options = [...widget.draft.options];
    if (changedOptionIndex != null && optionValue != null) {
      options[changedOptionIndex] = optionValue;
    }
    widget.onChanged(
      widget.draft.copyWith(
        text: text,
        options: options,
        correctIndex: correctIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              decoration: InputDecoration(labelText: 'السؤال ${widget.number}'),
              onChanged: (value) => _emitDraft(text: value),
            ),
            RadioGroup<int>(
              groupValue: widget.draft.correctIndex,
              onChanged: (value) {
                if (value != null) _emitDraft(correctIndex: value);
              },
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < _optionControllers.length;
                    index++
                  )
                    TextField(
                      controller: _optionControllers[index],
                      decoration: InputDecoration(
                        labelText: 'الاختيار ${index + 1}',
                        suffixIcon: Radio<int>(value: index),
                      ),
                      onChanged: (value) => _emitDraft(
                        changedOptionIndex: index,
                        optionValue: value,
                      ),
                    ),
                ],
              ),
            ),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('اختاري الإجابة الصحيحة من الدوائر'),
            ),
          ],
        ),
      ),
    );
  }
}
