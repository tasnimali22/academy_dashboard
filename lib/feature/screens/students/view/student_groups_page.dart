import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/core/theme/app_text_styles.dart';
import 'package:codingacademy_admin/core/services/student_groups_service.dart';
import 'package:codingacademy_admin/core/services/student_accounts_service.dart';
import 'package:flutter/material.dart';

class StudentGroupsPage extends StatelessWidget {
  const StudentGroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: StudentGroupsService.watchStudents(),
      builder: (context, studentsSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: StudentGroupsService.watchGroups(),
          builder: (context, groupsSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: StudentGroupsService.watchCourses(),
              builder: (context, coursesSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: StudentGroupsService.watchExams(),
                  builder: (context, examsSnapshot) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: StudentAccountsService.watchAdmins(),
                      builder: (context, adminsSnapshot) {
                        final error =
                            studentsSnapshot.error ??
                            groupsSnapshot.error ??
                            coursesSnapshot.error ??
                            examsSnapshot.error ??
                            adminsSnapshot.error;
                        final adminIds =
                            adminsSnapshot.data?.docs
                                .map((admin) => admin.id)
                                .toSet() ??
                            <String>{};
                        final students =
                            studentsSnapshot.data?.docs
                                .where(
                                  (student) => !adminIds.contains(student.id),
                                )
                                .toList() ??
                            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                        return Scaffold(
                          appBar: AppBar(
                            title: const Text('الطلاب والمجموعات'),
                          ),
                          floatingActionButton: FloatingActionButton.extended(
                            onPressed:
                                studentsSnapshot.hasData &&
                                    adminsSnapshot.hasData
                                ? () => _editGroup(context, students)
                                : null,
                            icon: const Icon(Icons.group_add_outlined),
                            label: const Text('إنشاء مجموعة'),
                          ),
                          body: error != null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'تعذر تحميل الطلاب أو المجموعات: $error',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : !studentsSnapshot.hasData ||
                                    !adminsSnapshot.hasData
                              ? const Center(child: CircularProgressIndicator())
                              : _buildContent(
                                  context,
                                  students,
                                  groupsSnapshot,
                                  coursesSnapshot,
                                  examsSnapshot,
                                ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> students,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> groupsSnapshot,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> coursesSnapshot,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> examsSnapshot,
  ) {
    if (!groupsSnapshot.hasData ||
        !coursesSnapshot.hasData ||
        !examsSnapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final courses = coursesSnapshot.data!.docs;
    final exams = examsSnapshot.data!.docs;
    final studentNames = {
      for (final student in students) student.id: _studentName(student),
    };
    final groups = groupsSnapshot.data!.docs;
    if (students.isEmpty) {
      return const Center(child: Text('لا توجد ملفات طلاب بعد.'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('الطلاب المسجلون'),
            subtitle: Text('${students.length} طالب'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text('كل الطلاب'),
        ),
        for (final student in students)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(studentNames[student.id] ?? student.id),
              subtitle: Text(student.data()['email'] as String? ?? ''),
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text('مجموعاتي'),
        ),
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('أنشئي مجموعة واختاري الطلاب لإدارة صلاحياتهم معًا.'),
          ),
        for (final group in groups)
          _groupCard(context, group, students, studentNames, courses, exams),
      ],
    );
  }

  Widget _groupCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> group,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> students,
    Map<String, String> studentNames,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> courses,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> exams,
  ) {
    final data = group.data();
    final memberIds = (data['memberIds'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    final shownNames = memberIds
        .map((id) => studentNames[id])
        .whereType<String>()
        .take(3)
        .join('، ');
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
        title: Text(data['name'] as String? ?? 'مجموعة'),
        subtitle: Text(
          '${memberIds.length} طالب'
          '${shownNames.isEmpty ? '' : '\n$shownNames'}'
          '${memberIds.length > 3 ? '، ...' : ''}',
        ),
        isThreeLine: memberIds.length > 3 || shownNames.isNotEmpty,
        trailing: PopupMenuButton<String>(
          tooltip: 'إدارة المجموعة',
          onSelected: (action) async {
            switch (action) {
              case 'edit':
                await _editGroup(
                  context,
                  students,
                  groupId: group.id,
                  initialName: data['name'] as String? ?? '',
                  initialMembers: memberIds,
                );
              case 'course':
                await _grantFromList(
                  context,
                  memberIds,
                  courses,
                  isCourse: true,
                );
              case 'exam':
                await _grantFromList(
                  context,
                  memberIds,
                  exams,
                  isCourse: false,
                );
              case 'appointment':
                await _createAppointment(context, memberIds, courses);
              case 'delete':
                await _deleteGroup(context, group.reference);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('تعديل الطلاب')),
            PopupMenuItem(value: 'course', child: Text('صلاحية كورس')),
            PopupMenuItem(value: 'exam', child: Text('صلاحية امتحان')),
            PopupMenuItem(
              value: 'appointment',
              child: Text('إرسال موعد للمجموعة'),
            ),
            PopupMenuItem(value: 'delete', child: Text('حذف المجموعة')),
          ],
        ),
      ),
    );
  }

  Future<void> _editGroup(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> students, {
    String? groupId,
    String initialName = '',
    Set<String> initialMembers = const {},
  }) async {
    final result = await showDialog<({String name, Set<String> memberIds})>(
      context: context,
      builder: (_) => _GroupDialog(
        students: students,
        initialName: initialName,
        initialMembers: initialMembers,
      ),
    );
    if (!context.mounted || result == null) return;
    try {
      await StudentGroupsService.saveGroup(
        groupId: groupId,
        name: result.name,
        memberIds: result.memberIds,
      );
      if (!context.mounted) return;
      _notify(
        context,
        groupId == null ? 'تم إنشاء المجموعة' : 'تم تحديث المجموعة',
      );
    } catch (error) {
      if (!context.mounted) return;
      _notify(context, 'تعذر حفظ المجموعة: $error');
    }
  }

  Future<void> _grantFromList(
    BuildContext context,
    Set<String> memberIds,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> options, {
    required bool isCourse,
  }) async {
    if (options.isEmpty) {
      _notify(
        context,
        isCourse ? 'أضيفي كورسًا أولًا' : 'أضيفي امتحانًا أولًا',
      );
      return;
    }
    final id = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(isCourse ? 'منح صلاحية كورس' : 'منح صلاحية امتحان'),
        children: [
          for (final option in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, option.id),
              child: Text(option.data()['title'] as String? ?? option.id),
            ),
        ],
      ),
    );
    if (!context.mounted || id == null) return;
    try {
      if (isCourse) {
        final ownerId =
            options.firstWhere((option) => option.id == id).data()['createdBy']
                as String? ??
            StudentGroupsService.legacyResourceOwnerId;
        await StudentGroupsService.grantCourse(memberIds, id, ownerId);
      } else {
        final ownerId =
            options.firstWhere((option) => option.id == id).data()['createdBy']
                as String? ??
            StudentGroupsService.legacyResourceOwnerId;
        await StudentGroupsService.grantExam(memberIds, id, ownerId);
      }
      if (!context.mounted) return;
      _notify(context, 'تم تحديث صلاحيات ${memberIds.length} طالب');
    } catch (error) {
      if (!context.mounted) return;
      _notify(context, 'تعذر تحديث الصلاحيات: $error');
    }
  }

  Future<void> _createAppointment(
    BuildContext context,
    Set<String> memberIds,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> courses,
  ) async {
    if (courses.isEmpty) {
      _notify(context, 'أضيفي كورسًا قبل إنشاء موعد');
      return;
    }
    final appointment = await showDialog<_AppointmentDraft>(
      context: context,
      builder: (_) => _AppointmentDraftDialog(courses: courses),
    );
    if (!context.mounted || appointment == null) return;
    try {
      await StudentGroupsService.createGroupAppointment(
        memberIds: memberIds,
        courseId: appointment.courseId,
        courseTitle: appointment.courseTitle,
        title: appointment.title,
        description: appointment.description,
        startsAt: appointment.startsAt,
      );
      if (!context.mounted) return;
      _notify(context, 'تم إرسال الموعد إلى أعضاء المجموعة');
    } catch (error) {
      if (!context.mounted) return;
      _notify(context, 'تعذر إنشاء الموعد: $error');
    }
  }

  Future<void> _deleteGroup(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المجموعة'),
        content: const Text('سيتم حذف المجموعة، دون حذف حسابات الطلاب.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    try {
      await reference.delete();
      if (!context.mounted) return;
      _notify(context, 'تم حذف المجموعة');
    } catch (error) {
      if (!context.mounted) return;
      _notify(context, 'تعذر حذف المجموعة: $error');
    }
  }

  static String _studentName(
    QueryDocumentSnapshot<Map<String, dynamic>> student,
  ) {
    final data = student.data();
    final name = (data['name'] as String?)?.trim();
    final email = (data['email'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (email != null && email.isNotEmpty) return email;
    return student.id;
  }

  static void _notify(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _GroupDialog extends StatefulWidget {
  const _GroupDialog({
    required this.students,
    required this.initialName,
    required this.initialMembers,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> students;
  final String initialName;
  final Set<String> initialMembers;

  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  late final _nameController = TextEditingController(text: widget.initialName);
  late final _members = {...widget.initialMembers};
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialName.isEmpty ? 'إنشاء مجموعة' : 'تعديل المجموعة',
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم المجموعة'),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(
                _error!,
                style: AppTextStyles.error(context),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final student in widget.students)
                    CheckboxListTile(
                      value: _members.contains(student.id),
                      title: Text(StudentGroupsPage._studentName(student)),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _members.add(student.id);
                          } else {
                            _members.remove(student.id);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty || _members.isEmpty) {
              setState(
                () => _error =
                    'اكتبي اسم المجموعة واختاري طالبًا واحدًا على الأقل.',
              );
              return;
            }
            Navigator.pop(context, (
              name: _nameController.text.trim(),
              memberIds: _members,
            ));
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _AppointmentDraft {
  const _AppointmentDraft({
    required this.courseId,
    required this.courseTitle,
    required this.title,
    required this.description,
    required this.startsAt,
  });

  final String courseId;
  final String courseTitle;
  final String title;
  final String description;
  final DateTime startsAt;
}

class _AppointmentDraftDialog extends StatefulWidget {
  const _AppointmentDraftDialog({required this.courses});
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> courses;

  @override
  State<_AppointmentDraftDialog> createState() =>
      _AppointmentDraftDialogState();
}

class _AppointmentDraftDialogState extends State<_AppointmentDraftDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  late String _courseId = widget.courses.first.id;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  TimeOfDay _time = TimeOfDay.now();
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('موعد للمجموعة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'عنوان الموعد'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _courseId,
              decoration: const InputDecoration(labelText: 'الكورس المرتبط'),
              items: [
                for (final course in widget.courses)
                  DropdownMenuItem(
                    value: course.id,
                    child: Text(course.data()['title'] as String? ?? course.id),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _courseId = value);
              },
            ),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'التفاصيل'),
              maxLines: 2,
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (selected != null && mounted) {
                      setState(() => _date = DateUtils.dateOnly(selected));
                    }
                  },
                  child: Text(
                    MaterialLocalizations.of(context).formatMediumDate(_date),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (selected != null && mounted) {
                      setState(() => _time = selected);
                    }
                  },
                  child: Text(_time.format(context)),
                ),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                style: AppTextStyles.error(context),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) {
              setState(() => _error = 'أدخلي عنوان الموعد');
              return;
            }
            final course = widget.courses.firstWhere(
              (item) => item.id == _courseId,
            );
            Navigator.pop(
              context,
              _AppointmentDraft(
                courseId: course.id,
                courseTitle: course.data()['title'] as String? ?? course.id,
                title: _title.text.trim(),
                description: _description.text.trim(),
                startsAt: DateTime(
                  _date.year,
                  _date.month,
                  _date.day,
                  _time.hour,
                  _time.minute,
                ),
              ),
            );
          },
          child: const Text('إرسال'),
        ),
      ],
    );
  }
}
