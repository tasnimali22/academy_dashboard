import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/core/services/admin_access_service.dart';
import 'package:codingacademy_admin/feature/screens/attendance/data/model/student_attendance_report.dart';

class AttendanceReportService {
  AttendanceReportService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<AttendanceReport> loadReport() async {
    final role = await AdminAccessService.currentRole();
    if (role == null) throw StateError('ليس لديك صلاحية عرض الإحصاءات.');

    final courses = await AdminAccessService.loadContent('courses');
    final projects = await AdminAccessService.loadContent('projects');
    final snapshots = await Future.wait([
      _firestore.collection('users').get(),
      _firestore.collection('admins').get(),
    ]);
    final adminIds = snapshots[1].docs.map((document) => document.id).toSet();
    final studentData = {
      for (final student in snapshots[0].docs)
        if (!adminIds.contains(student.id)) student.id: student.data(),
    };
    final attendanceByCourse = await Future.wait(
      courses.docs.map(
        (course) => _firestore
            .collection('attendance')
            .where('courseId', isEqualTo: course.id)
            .get(),
      ),
    );
    final attendanceCounts = <String, List<int>>{};
    final projectCounts = <String, int>{};
    final relevantStudents = <String>{};

    for (var index = 0; index < courses.docs.length; index++) {
      final course = courses.docs[index];
      final configuredOwner = course.data()['createdBy'] as String?;
      final ownerId = configuredOwner == null || configuredOwner.isEmpty
          ? 'legacy'
          : configuredOwner;

      for (final entry in studentData.entries) {
        final data = entry.value;
        final courseIds = data['courseIds'] as List? ?? const [];
        final grants = data['adminCourseGrants'];
        final ownerGrants = grants is Map
            ? grants[ownerId] as List? ?? const []
            : const [];
        if (courseIds.contains(course.id) || ownerGrants.contains(course.id)) {
          relevantStudents.add(entry.key);
        }
      }

      for (final document in attendanceByCourse[index].docs) {
        final records = document.data()['records'];
        if (records is! Map) continue;
        for (final entry in records.entries) {
          final studentId = entry.key.toString();
          if (!studentData.containsKey(studentId) || entry.value is! bool) {
            continue;
          }
          relevantStudents.add(studentId);
          final counts = attendanceCounts.putIfAbsent(studentId, () => [0, 0]);
          counts[1]++;
          if (entry.value == true) counts[0]++;
        }
      }
    }

    for (final project in projects.docs) {
      final targetUserIds = project.data()['targetUserIds'];
      if (targetUserIds is! List) continue;
      for (final id in targetUserIds.whereType<String>()) {
        if (!studentData.containsKey(id)) continue;
        relevantStudents.add(id);
        projectCounts.update(
          id,
          (projectTotal) => projectTotal + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final rows = relevantStudents.map((id) {
      final data = studentData[id]!;
      final counts = attendanceCounts[id] ?? [0, 0];
      final name = (data['name'] as String?)?.trim();
      return StudentAttendanceReport(
        name: name == null || name.isEmpty
            ? data['email'] as String? ?? id
            : name,
        present: counts[0],
        total: counts[1],
        projects: projectCounts[id] ?? 0,
      );
    }).toList()..sort((first, second) => first.name.compareTo(second.name));

    return AttendanceReport(rows);
  }

  Future<void> syncPastAttendance() async {
    await AdminAccessService.requireUserId();
    final courses = await AdminAccessService.loadContent('courses');

    for (final course in courses.docs) {
      final attendance = await _firestore
          .collection('attendance')
          .where('courseId', isEqualTo: course.id)
          .get();
      for (final document in attendance.docs) {
        final data = document.data();
        final records = data['records'];
        if (records is! Map) continue;

        final writes = records.entries
            .where((entry) => entry.value is bool)
            .toList();
        for (var start = 0; start < writes.length; start += 450) {
          final batch = _firestore.batch();
          for (final entry in writes.skip(start).take(450)) {
            batch.set(
              _firestore
                  .collection('users')
                  .doc(entry.key.toString())
                  .collection('attendance')
                  .doc(document.id),
              {
                'courseId': course.id,
                'createdBy': data['createdBy'] ?? course.data()['createdBy'],
                'date': data['date'],
                'present': entry.value,
                'updatedAt': FieldValue.serverTimestamp(),
              },
            );
          }
          await batch.commit();
        }
      }
    }
  }
}
