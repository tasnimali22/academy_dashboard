import 'package:codingacademy_admin/feature/screens/attendance/data/cubit/attendance_report_cubit.dart';
import 'package:codingacademy_admin/feature/screens/attendance/data/cubit/attendance_report_state.dart';
import 'package:codingacademy_admin/feature/screens/attendance/data/model/student_attendance_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AttendanceReportPage extends StatelessWidget {
  const AttendanceReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AttendanceReportCubit(),
      child: BlocConsumer<AttendanceReportCubit, AttendanceReportState>(
        listenWhen: (previous, current) =>
            previous.errorMessage != current.errorMessage ||
            previous.notification != current.notification,
        listener: (context, state) {
          final message = state.errorMessage ?? state.notification;
          if (message == null) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          context.read<AttendanceReportCubit>().clearMessages();
        },
        builder: (context, state) {
          final cubit = context.read<AttendanceReportCubit>();
          return Scaffold(
            appBar: AppBar(
              title: const Text('إحصائيات الحضور'),
              actions: [
                IconButton(
                  tooltip: 'تحديث',
                  onPressed: state.loading ? null : cubit.load,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'تجهيز سجلات الحضور السابقة للطلاب',
                  onPressed: state.syncing ? null : cubit.syncPastAttendance,
                  icon: state.syncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                ),
              ],
            ),
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, AttendanceReportState state) {
    if (state.report == null) {
      if (state.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.errorMessage ?? 'تعذر تحميل الإحصاءات.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: context.read<AttendanceReportCubit>().load,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final report = state.report!;
    return Stack(
      children: [
        _ReportContent(report: report),
        if (state.loading)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.report});

  final AttendanceReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.fact_check_outlined)),
            title: Text('نسبة الحضور: ${report.percentage}%'),
            subtitle: Text(
              '${report.totalPresent} حضور من ${report.totalSessions} تسجيل طالب',
            ),
          ),
        ),
        Expanded(
          child: report.students.isEmpty
              ? const Center(child: Text('لا توجد بيانات طلاب لعرضها'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: report.students.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final student = report.students[index];
                    return Card(
                      child: ListTile(
                        title: Text(student.name),
                        subtitle: Text(
                          '${student.present} من ${student.total} سجل حضور'
                          ' • ${student.projects} مشروع',
                        ),
                        trailing: Text(
                          '${student.percentage}%',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
