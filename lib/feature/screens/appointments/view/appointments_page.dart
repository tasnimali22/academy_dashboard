import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/core/utils/confirm_dialog.dart';
import 'package:flutter/material.dart';

class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .orderBy('order')
          .snapshots(),
      builder: (context, coursesSnapshot) {
        final courses = coursesSnapshot.data?.docs ?? [];
        return Scaffold(
          appBar: AppBar(
            title: const Text('المواعيد'),
            actions: [
              IconButton(
                tooltip: 'إضافة موعد',
                onPressed: courses.isEmpty
                    ? null
                    : () => _addAppointment(context, courses),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          body: _buildBody(context, coursesSnapshot, courses),
          floatingActionButton: courses.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _addAppointment(context, courses),
                  icon: const Icon(Icons.add),
                  label: const Text('موعد جديد'),
                ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> coursesSnapshot,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> courses,
  ) {
    if (coursesSnapshot.hasError) {
      return const Center(child: Text('تعذر تحميل الكورسات'));
    }
    if (!coursesSnapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (courses.isEmpty) {
      return const Center(child: Text('أضيفي كورسًا قبل إضافة المواعيد'));
    }

    final courseNames = {
      for (final course in courses)
        course.id: course.data()['title'] as String? ?? course.id,
    };

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('appointments').snapshots(),
      builder: (context, appointmentsSnapshot) {
        if (appointmentsSnapshot.hasError) {
          return const Center(child: Text('تعذر تحميل المواعيد'));
        }
        if (!appointmentsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointments = appointmentsSnapshot.data!.docs.toList()
          ..sort((first, second) {
            final firstDate = first.data()['startsAt'];
            final secondDate = second.data()['startsAt'];
            final firstTime = firstDate is Timestamp
                ? firstDate.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            final secondTime = secondDate is Timestamp
                ? secondDate.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            return firstTime.compareTo(secondTime);
          });

        if (appointments.isEmpty) {
          return const Center(child: Text('لا توجد مواعيد. أضيفي أول موعد.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          itemCount: appointments.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final appointment = appointments[index];
            final data = appointment.data();
            final timestamp = data['startsAt'];
            final startsAt = timestamp is Timestamp ? timestamp.toDate() : null;
            final courseId = data['courseId'] as String? ?? '';
            final description = data['description'] as String? ?? '';

            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.calendar_month_outlined),
                ),
                title: Text(data['title'] as String? ?? 'موعد'),
                subtitle: Text(
                  [
                    courseNames[courseId] ?? data['courseTitle'] ?? courseId,
                    if (startsAt != null) _formatDateTime(context, startsAt),
                    if (description.trim().isNotEmpty) description.trim(),
                  ].join('\n'),
                ),
                isThreeLine: description.trim().isNotEmpty,
                trailing: IconButton(
                  tooltip: 'حذف الموعد',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final confirmed = await confirmDelete(
                      context,
                      'هل تريدين حذف هذا الموعد؟',
                    );
                    if (!confirmed || !context.mounted) return;
                    try {
                      await appointment.reference.delete();
                    } on FirebaseException catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تعذر حذف الموعد: ${_firebaseErrorMessage(error)}',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addAppointment(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> courses,
  ) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AppointmentDialog(courses: courses),
    );
    if (added == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تمت إضافة الموعد')));
    }
  }

  String _formatDateTime(BuildContext context, DateTime dateTime) {
    final date = MaterialLocalizations.of(context).formatMediumDate(dateTime);
    final time = TimeOfDay.fromDateTime(dateTime).format(context);
    return '$date • $time';
  }

  String _firebaseErrorMessage(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return 'تحققي من نشر قواعد Firestore ومن وجود حساب الإدارة في '
          'admins/{uid} بمشروع code-acadmy.';
    }
    return error.message ?? error.code;
  }
}

class _AppointmentDialog extends StatefulWidget {
  const _AppointmentDialog({required this.courses});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> courses;

  @override
  State<_AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends State<_AppointmentDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late String _courseId;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  TimeOfDay _time = TimeOfDay.now();
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _courseId = widget.courses.first.id;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      setState(() => _date = DateUtils.dateOnly(selected));
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) {
      setState(() => _time = selected);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'اكتبي اسم الموعد');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final startsAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final course = widget.courses.firstWhere((item) => item.id == _courseId);
    try {
      await FirebaseFirestore.instance.collection('appointments').add({
        'title': title,
        'description': _descriptionController.text.trim(),
        'courseId': course.id,
        'courseTitle': course.data()['title'] as String? ?? course.id,
        'startsAt': Timestamp.fromDate(startsAt),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, true);
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = 'تعذر حفظ الموعد: ${_firebaseErrorMessage(error)}';
        });
      }
    }
  }

  String _firebaseErrorMessage(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return 'رفضت قواعد Firestore العملية. انشري firestore.rules بمشروع '
          'code-acadmy وتأكدي من وجود حساب الإدارة الحالي في admins/{uid}.';
    }
    return error.message ?? error.code;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة موعد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'اسم الموعد'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _courseId,
              decoration: const InputDecoration(labelText: 'الكورس'),
              items: [
                for (final course in widget.courses)
                  DropdownMenuItem(
                    value: course.id,
                    child: Text(course.data()['title'] as String? ?? course.id),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _courseId = value);
                    },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      MaterialLocalizations.of(context).formatMediumDate(_date),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(_time.format(context)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'تفاصيل إضافية (اختياري)',
              ),
              maxLines: 2,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
