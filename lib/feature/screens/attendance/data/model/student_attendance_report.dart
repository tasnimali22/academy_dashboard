class StudentAttendanceReport {
  const StudentAttendanceReport({
    required this.name,
    required this.present,
    required this.total,
    required this.projects,
  });

  final String name;
  final int present;
  final int total;
  final int projects;

  int get percentage => total == 0 ? 0 : (present * 100 / total).round();
}

class AttendanceReport {
  const AttendanceReport(this.students);

  final List<StudentAttendanceReport> students;

  int get totalPresent =>
      students.fold(0, (total, student) => total + student.present);

  int get totalSessions =>
      students.fold(0, (total, student) => total + student.total);

  int get percentage =>
      totalSessions == 0 ? 0 : (totalPresent * 100 / totalSessions).round();
}
