import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/core/services/student_accounts_service.dart';
import 'package:flutter/material.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  String? _courseId;
  String? _loadedDocumentId;
  Map<String, bool> _marks = {};
  bool _loadingMarks = false;
  bool _saving = false;
  bool _refreshingStudents = false;
  Set<String> _adminIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAdminIds();
    });
  }

  Future<void> _loadAdminIds() async {
    try {
      final adminIds = await StudentAccountsService.loadAdminIds();
      if (mounted) setState(() => _adminIds = adminIds);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل حسابات الإدارة: ${error.message}')),
      );
    }
  }

  Future<void> _refreshStudents() async {
    if (_refreshingStudents) return;
    setState(() => _refreshingStudents = true);
    try {
      final result = await StudentAccountsService.refresh();
      if (!mounted) return;
      setState(() => _adminIds = result.adminIds);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث قائمة الطلاب: ${result.studentCount} طالب'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث قائمة الطلاب: ${error.message}')),
      );
    } finally {
      if (mounted) setState(() => _refreshingStudents = false);
    }
  }

  String _documentId(String courseId, DateTime date) =>
      '$courseId-${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _loadMarks(String courseId) async {
    final documentId = _documentId(courseId, _date);
    setState(() {
      _loadingMarks = true;
      _loadedDocumentId = documentId;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(documentId)
          .get();
      if (!mounted || _loadedDocumentId != documentId) return;
      final rawMarks = snapshot.data()?['records'];
      setState(() {
        _marks = rawMarks is Map
            ? rawMarks.map(
                (key, value) => MapEntry(key.toString(), value == true),
              )
            : {};
        _loadingMarks = false;
      });
    } catch (error) {
      if (!mounted || _loadedDocumentId != documentId) return;
      setState(() => _loadingMarks = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تحميل سجل الحضور: $error')));
    }
  }

  Future<void> _chooseDate(String courseId) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateUtils.dateOnly(picked);
      _loadedDocumentId = null;
    });
    await _loadMarks(courseId);
  }

  Future<void> _save(
    String courseId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> students,
  ) async {
    final unmarked = students
        .where((student) => !_marks.containsKey(student.id))
        .length;
    if (unmarked > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('سجلي حالة $unmarked طالب قبل الحفظ')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final id = _documentId(courseId, _date);
      await FirebaseFirestore.instance.collection('attendance').doc(id).set({
        'courseId': courseId,
        'date': Timestamp.fromDate(_date),
        'records': {
          for (final student in students) student.id: _marks[student.id],
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ الحضور والغياب')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر حفظ الحضور: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحضور والغياب'),
        actions: [
          IconButton(
            tooltip: 'تحديث قائمة الطلاب',
            onPressed: _refreshingStudents ? null : _refreshStudents,
            icon: _refreshingStudents
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('courses')
            .orderBy('order')
            .snapshots(),
        builder: (context, coursesSnapshot) {
          if (coursesSnapshot.hasError) {
            return const Center(child: Text('تعذر تحميل الكورسات'));
          }
          if (!coursesSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final courses = coursesSnapshot.data!.docs;
          if (courses.isEmpty) {
            return const Center(child: Text('أضيفي كورسًا قبل تسجيل الحضور'));
          }
          final selectedCourse = courses.any((course) => course.id == _courseId)
              ? _courseId!
              : courses.first.id;
          final documentId = _documentId(selectedCourse, _date);
          if (_loadedDocumentId != documentId && !_loadingMarks) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _loadedDocumentId != documentId) {
                _loadMarks(selectedCourse);
              }
            });
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedCourse,
                        decoration: const InputDecoration(
                          labelText: 'الكورس',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final course in courses)
                            DropdownMenuItem(
                              value: course.id,
                              child: Text(course.data()['title'] ?? course.id),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _courseId = value;
                            _loadedDocumentId = null;
                          });
                          _loadMarks(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _chooseDate(selectedCourse),
                      icon: const Icon(Icons.calendar_month),
                      label: Text('${_date.day}/${_date.month}/${_date.year}'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, studentsSnapshot) {
                    if (studentsSnapshot.hasError) {
                      return const Center(child: Text('تعذر تحميل الطلاب'));
                    }
                    if (!studentsSnapshot.hasData || _loadingMarks) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final students = studentsSnapshot.data!.docs.where((user) {
                      if (_adminIds.contains(user.id)) return false;
                      final ids = (user.data()['courseIds'] as List?) ?? [];
                      return ids.contains(selectedCourse);
                    }).toList();
                    if (students.isEmpty) {
                      return const Center(
                        child: Text(
                          'لا يوجد طلاب مُسند لهم هذا الكورس. '
                          'أضيفي صلاحية الكورس من صفحة الطلاب.',
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              final student = students[index];
                              final data = student.data();
                              final name = (data['name'] as String?)?.trim();
                              final email =
                                  (data['email'] as String?)?.trim() ?? '';
                              final status = _marks[student.id];
                              return Card(
                                child: ListTile(
                                  title: Text(
                                    name == null || name.isEmpty
                                        ? email.isEmpty
                                              ? student.id
                                              : email
                                        : name,
                                  ),
                                  subtitle: Text(
                                    status == null
                                        ? 'لم يتم تسجيل الحالة'
                                        : status
                                        ? 'حاضر'
                                        : 'غائب',
                                  ),
                                  trailing: Wrap(
                                    spacing: 4,
                                    children: [
                                      _MarkButton(
                                        label: 'حاضر',
                                        selected: status == true,
                                        color: Colors.green,
                                        onPressed: () => setState(
                                          () => _marks[student.id] = true,
                                        ),
                                      ),
                                      _MarkButton(
                                        label: 'غائب',
                                        selected: status == false,
                                        color: Colors.red,
                                        onPressed: () => setState(
                                          () => _marks[student.id] = false,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => _save(selectedCourse, students),
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: const Text('حفظ سجل الحضور'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: selected ? Colors.white : color,
        backgroundColor: selected ? color : color.withValues(alpha: 0.12),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
