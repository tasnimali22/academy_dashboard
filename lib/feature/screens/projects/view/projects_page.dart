import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/core/services/projects_service.dart';
import 'package:codingacademy_admin/core/theme/app_text_styles.dart';
import 'package:codingacademy_admin/core/utils/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ProjectsService.watchProjects(),
      builder: (context, snapshot) {
        final projects = snapshot.data?.docs.toList() ?? [];
        projects.sort((first, second) {
          final firstDate = first.data()['createdAt'];
          final secondDate = second.data()['createdAt'];
          final firstMillis = firstDate is Timestamp
              ? firstDate.millisecondsSinceEpoch
              : 0;
          final secondMillis = secondDate is Timestamp
              ? secondDate.millisecondsSinceEpoch
              : 0;
          return secondMillis.compareTo(firstMillis);
        });
        return Scaffold(
          appBar: AppBar(title: const Text('الأعمال والمشاريع')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreateDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('إضافة مشروع'),
          ),
          body: _buildBody(context, snapshot, projects),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> projects,
  ) {
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('تعذر تحميل المشاريع: ${snapshot.error}'),
        ),
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (projects.isEmpty) {
      return const Center(
        child: Text('لا توجد مشاريع بعد. أضيفي أول تكليف للطلاب.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: projects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final project = projects[index];
        final data = project.data();
        final dueAt = data['dueAt'];
        final dueDate = dueAt is Timestamp ? dueAt.toDate() : null;
        final accessCount = (data['targetUserIds'] as List? ?? []).length;
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.work_outline)),
            title: Text(data['title'] as String? ?? 'مشروع'),
            subtitle: Text(
              [
                if (dueDate != null)
                  'آخر موعد: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
                'متاح لـ $accessCount طالب',
                data['description'] as String? ?? '',
              ].where((line) => line.isNotEmpty).join('\n'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: dueDate != null,
            trailing: PopupMenuButton<String>(
              tooltip: 'إدارة المشروع',
              onSelected: (action) {
                if (action == 'edit') _showEditDialog(context, project);
                if (action == 'delete') _deleteProject(context, project);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('تعديل'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('حذف'),
                  ),
                ),
              ],
            ),
            onTap: () => _showSubmissions(context, project),
          ),
        );
      },
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _ProjectFormDialog(),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم نشر المشروع للطلاب')));
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> project,
  ) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _ProjectFormDialog(project: project),
    );
    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث المشروع')));
    }
  }

  Future<void> _deleteProject(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> project,
  ) async {
    final confirmed = await confirmDelete(
      context,
      'سيتم حذف المشروع وجميع الحلول والتقييمات المرتبطة به. هل تريدين المتابعة؟',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ProjectsService.deleteProject(project.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المشروع وتسليماته')),
        );
      }
    } on FirebaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حذف المشروع: ${error.message}')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حذف المشروع: $error')));
      }
    }
  }

  Future<void> _showSubmissions(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> project,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SubmissionsDialog(project: project),
    );
  }
}

class _ProjectFormDialog extends StatefulWidget {
  const _ProjectFormDialog({this.project});

  final QueryDocumentSnapshot<Map<String, dynamic>>? project;

  @override
  State<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<_ProjectFormDialog> {
  late final Map<String, dynamic> _initialData =
      widget.project?.data() ?? const <String, dynamic>{};
  late final _title = TextEditingController(
    text: _initialData['title'] as String? ?? '',
  );
  late final _description = TextEditingController(
    text: _initialData['description'] as String? ?? '',
  );
  late final _attachmentUrl = TextEditingController(
    text: _initialData['attachmentUrl'] as String? ?? '',
  );
  late final Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _studentsFuture = ProjectsService.loadStudents();
  late final Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _groupsFuture = ProjectsService.loadCurrentAdminGroups();
  late Set<String> _studentIds = (_initialData['targetUserIds'] as List? ?? [])
      .whereType<String>()
      .toSet();
  late Set<String> _groupIds = (_initialData['targetGroupIds'] as List? ?? [])
      .whereType<String>()
      .toSet();
  late DateTime? _dueAt = (_initialData['dueAt'] as Timestamp?)?.toDate();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _attachmentUrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    setState(() => _dueAt = date);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _description.text.trim().isEmpty) {
      setState(() => _error = 'اكتبي اسم المشروع والتعليمات.');
      return;
    }
    if (_studentIds.isEmpty) {
      setState(() => _error = 'اختاري الطلاب المسموح لهم برؤية المشروع.');
      return;
    }
    final attachment = _attachmentUrl.text.trim();
    if (attachment.isNotEmpty && !_isWebUrl(attachment)) {
      setState(() => _error = 'رابط الملف يجب أن يبدأ بـ https://');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.project == null) {
        await ProjectsService.createProject(
          title: title,
          description: _description.text,
          attachmentUrl: attachment,
          studentIds: _studentIds,
          groupIds: _groupIds,
          dueAt: _dueAt,
        );
      } else {
        await ProjectsService.updateProject(
          projectId: widget.project!.id,
          title: title,
          description: _description.text,
          attachmentUrl: attachment,
          studentIds: _studentIds,
          groupIds: _groupIds,
          dueAt: _dueAt,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر نشر المشروع: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.project != null;
    return AlertDialog(
      title: Text(isEditing ? 'تعديل المشروع' : 'إضافة مشروع'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'اسم المشروع'),
              ),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'وصف المشروع وتعليماته',
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _saving ? null : _chooseStudents,
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(
                    _studentIds.isEmpty
                        ? 'اختيار طلاب أو مجموعات'
                        : 'الوصول: ${_studentIds.length} طالب'
                              '${_groupIds.isEmpty ? '' : ' • ${_groupIds.length} مجموعة'}',
                  ),
                ),
              ),
              TextField(
                controller: _attachmentUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'رابط ملف التكليف (اختياري)',
                  hintText: 'https://drive.google.com/...',
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _pickDueDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _dueAt == null
                        ? 'تحديد آخر موعد (اختياري)'
                        : 'آخر موعد: ${_dueAt!.day}/${_dueAt!.month}/${_dueAt!.year}',
                  ),
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: AppTextStyles.error(context),
                ),
            ],
          ),
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
              : Text(isEditing ? 'حفظ التعديلات' : 'نشر للطلاب'),
        ),
      ],
    );
  }

  Future<void> _chooseStudents() async {
    try {
      final students = await _studentsFuture;
      final groups = await _groupsFuture;
      if (!mounted) return;
      final selected = await showDialog<_ProjectAccessSelection>(
        context: context,
        builder: (_) => _StudentPickerDialog(
          students: students,
          groups: groups,
          initialSelection: _studentIds,
          initialGroupSelection: _groupIds,
        ),
      );
      if (selected != null && mounted) {
        setState(() {
          _studentIds = selected.studentIds;
          _groupIds = selected.groupIds;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تحميل الطلاب: $error');
    }
  }
}

class _SubmissionsDialog extends StatelessWidget {
  const _SubmissionsDialog({required this.project});

  final QueryDocumentSnapshot<Map<String, dynamic>> project;

  @override
  Widget build(BuildContext context) {
    final data = project.data();
    return AlertDialog(
      title: Text(data['title'] as String? ?? 'تسليمات المشروع'),
      content: SizedBox(
        width: 520,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ProjectsService.watchSubmissions(project.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('تعذر تحميل التسليمات: ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final submissions = snapshot.data!.docs;
            if (submissions.isEmpty) {
              return const Text('لم يرسل الطلاب حلولًا حتى الآن.');
            }
            return ListView.separated(
              shrinkWrap: true,
              itemCount: submissions.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final submission = submissions[index];
                final answer = submission.data();
                final grade = answer['grade'];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    answer['studentName'] as String? ??
                        answer['studentEmail'] as String? ??
                        submission.id,
                  ),
                  subtitle: Text(
                    grade is int ? 'التقييم: $grade / 100' : 'بانتظار التقييم',
                  ),
                  trailing: IconButton(
                    tooltip: 'فتح الحل وتقييمه',
                    icon: const Icon(Icons.rate_review_outlined),
                    onPressed: () => _grade(context, submission),
                  ),
                  onTap: () => _grade(context, submission),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _editAccess(context),
          icon: const Icon(Icons.manage_accounts_outlined),
          label: const Text('صلاحية الوصول'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }

  Future<void> _editAccess(BuildContext context) async {
    try {
      final students = await ProjectsService.loadStudents();
      final groups = await ProjectsService.loadCurrentAdminGroups();
      if (!context.mounted) return;
      final projectData = project.data();
      final currentIds = (projectData['targetUserIds'] as List? ?? [])
          .whereType<String>()
          .toSet();
      final currentGroupIds = (projectData['targetGroupIds'] as List? ?? [])
          .whereType<String>()
          .toSet();
      final selected = await showDialog<_ProjectAccessSelection>(
        context: context,
        builder: (_) => _StudentPickerDialog(
          students: students,
          groups: groups,
          initialSelection: currentIds,
          initialGroupSelection: currentGroupIds,
        ),
      );
      if (!context.mounted || selected == null) return;
      await ProjectsService.updateProjectAccess(
        projectId: project.id,
        studentIds: selected.studentIds,
        groupIds: selected.groupIds,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث صلاحيات الوصول للمشروع')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحديث الصلاحيات: $error')));
      }
    }
  }

  Future<void> _grade(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> submission,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _GradeSubmissionDialog(projectId: project.id, submission: submission),
    );
  }
}

class _StudentPickerDialog extends StatefulWidget {
  const _StudentPickerDialog({
    required this.students,
    required this.groups,
    required this.initialSelection,
    required this.initialGroupSelection,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> students;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> groups;
  final Set<String> initialSelection;
  final Set<String> initialGroupSelection;

  @override
  State<_StudentPickerDialog> createState() => _StudentPickerDialogState();
}

class _StudentPickerDialogState extends State<_StudentPickerDialog> {
  final _searchController = TextEditingController();
  late final Set<String> _selectedGroupIds = {...widget.initialGroupSelection};
  late final Set<String> _selectedStudentIds = _initialDirectStudentIds();
  String _search = '';
  String? _error;

  Set<String> _groupMemberIds(Iterable<String> groupIds) {
    final memberIds = <String>{};
    for (final group in widget.groups) {
      if (!groupIds.contains(group.id)) continue;
      memberIds.addAll(
        (group.data()['memberIds'] as List? ?? []).whereType<String>(),
      );
    }
    return memberIds;
  }

  Set<String> _initialDirectStudentIds() {
    return {...widget.initialSelection}
      ..removeAll(_groupMemberIds(_selectedGroupIds));
  }

  Set<String> get _selectedStudentIdsWithGroups => {
    ..._selectedStudentIds,
    ..._groupMemberIds(_selectedGroupIds),
  };

  void _toggleGroup(
    QueryDocumentSnapshot<Map<String, dynamic>> group,
    bool selected,
  ) {
    setState(() {
      if (selected) {
        _selectedGroupIds.add(group.id);
      } else {
        _selectedGroupIds.remove(group.id);
      }
      if (_selectedStudentIdsWithGroups.length > 500) {
        if (selected) {
          _selectedGroupIds.remove(group.id);
        } else {
          _selectedGroupIds.add(group.id);
        }
        _error = 'لا يمكن منح الوصول لأكثر من 500 طالب.';
        return;
      }
      _error = null;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _studentLabel(QueryDocumentSnapshot<Map<String, dynamic>> student) {
    final data = student.data();
    final name = (data['name'] as String? ?? '').trim();
    final email = (data['email'] as String? ?? '').trim();
    return name.isNotEmpty
        ? name
        : email.isNotEmpty
        ? email
        : student.id;
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = widget.students.where((student) {
      final data = student.data();
      final query = _search.trim().toLowerCase();
      return query.isEmpty ||
          _studentLabel(student).toLowerCase().contains(query) ||
          (data['email'] as String? ?? '').toLowerCase().contains(query);
    }).toList();
    return AlertDialog(
      title: Text(
        'الوصول: ${_selectedStudentIdsWithGroups.length} طالب • '
        '${_selectedGroupIds.length} مجموعة',
      ),
      content: SizedBox(
        width: 440,
        height: 520,
        child: Column(
          children: [
            if (widget.groups.isNotEmpty) ...[
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 4),
                  child: Text('مجموعاتي'),
                ),
              ),
              SizedBox(
                height: 132,
                child: ListView.builder(
                  itemCount: widget.groups.length,
                  itemBuilder: (context, index) {
                    final group = widget.groups[index];
                    final data = group.data();
                    final memberCount =
                        (data['memberIds'] as List? ?? []).length;
                    return CheckboxListTile(
                      dense: true,
                      value: _selectedGroupIds.contains(group.id),
                      title: Text(data['name'] as String? ?? 'مجموعة'),
                      subtitle: Text('$memberCount طالب'),
                      onChanged: (value) => _toggleGroup(group, value == true),
                    );
                  },
                ),
              ),
              const Divider(height: 12),
            ],
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'بحث بالاسم أو البريد',
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.students.isEmpty
                  ? const Center(child: Text('لا توجد حسابات طلاب.'))
                  : filteredStudents.isEmpty
                  ? const Center(child: Text('لا توجد نتائج مطابقة.'))
                  : ListView.builder(
                      itemCount: filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = filteredStudents[index];
                        final isGroupMember = _groupMemberIds(
                          _selectedGroupIds,
                        ).contains(student.id);
                        final selected =
                            isGroupMember ||
                            _selectedStudentIds.contains(student.id);
                        return CheckboxListTile(
                          value: selected,
                          title: Text(_studentLabel(student)),
                          subtitle: Text(
                            student.data()['email'] as String? ?? '',
                          ),
                          onChanged: (value) {
                            if (isGroupMember) return;
                            setState(() {
                              if (value == true) {
                                _selectedStudentIds.add(student.id);
                              } else {
                                _selectedStudentIds.remove(student.id);
                              }
                              _error = null;
                            });
                          },
                        );
                      },
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _error!,
                  style: AppTextStyles.error(context),
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
          onPressed:
              _selectedStudentIdsWithGroups.isEmpty ||
                  _selectedStudentIdsWithGroups.length > 500
              ? null
              : () => Navigator.pop(
                  context,
                  _ProjectAccessSelection(
                    studentIds: _selectedStudentIdsWithGroups,
                    groupIds: _selectedGroupIds,
                  ),
                ),
          child: const Text('تأكيد الصلاحية'),
        ),
      ],
    );
  }
}

class _ProjectAccessSelection {
  const _ProjectAccessSelection({
    required this.studentIds,
    required this.groupIds,
  });

  final Set<String> studentIds;
  final Set<String> groupIds;
}

class _GradeSubmissionDialog extends StatefulWidget {
  const _GradeSubmissionDialog({
    required this.projectId,
    required this.submission,
  });

  final String projectId;
  final QueryDocumentSnapshot<Map<String, dynamic>> submission;

  @override
  State<_GradeSubmissionDialog> createState() => _GradeSubmissionDialogState();
}

class _GradeSubmissionDialogState extends State<_GradeSubmissionDialog> {
  late final _grade = TextEditingController(
    text: widget.submission.data()['grade']?.toString() ?? '',
  );
  late final _feedback = TextEditingController(
    text: widget.submission.data()['feedback'] as String? ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _grade.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _openSubmission() async {
    final value = widget.submission.data()['solutionUrl'] as String? ?? '';
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) setState(() => _error = 'تعذر فتح رابط الحل.');
    }
  }

  Future<void> _save() async {
    final grade = int.tryParse(_grade.text.trim());
    if (grade == null || grade < 0 || grade > 100) {
      setState(() => _error = 'أدخلي تقييمًا صحيحًا من 0 إلى 100.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ProjectsService.gradeSubmission(
        projectId: widget.projectId,
        studentId: widget.submission.id,
        grade: grade,
        feedback: _feedback.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حفظ التقييم: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.submission.data();
    return AlertDialog(
      title: Text(
        data['studentName'] as String? ??
            data['studentEmail'] as String? ??
            widget.submission.id,
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _openSubmission,
                icon: const Icon(Icons.open_in_new),
                label: const Text('فتح رابط الحل'),
              ),
            ),
            TextField(
              controller: _grade,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'التقييم من 100'),
            ),
            TextField(
              controller: _feedback,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'ملاحظات للطالب'),
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
              : const Text('حفظ التقييم'),
        ),
      ],
    );
  }
}

bool _isWebUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.hasScheme &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty;
}
