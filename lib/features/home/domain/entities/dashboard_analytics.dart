import 'package:equatable/equatable.dart';

/// Today’s attendance analytics derived from roster + local attendance logs.
class DashboardAnalytics extends Equatable {
  const DashboardAnalytics({
    required this.reportDate,
    required this.totalEmployees,
    required this.presentCount,
    required this.absentCount,
    required this.lateCheckInCount,
    required this.attendancePercentage,
    required this.absentPercentage,
    required this.lateCheckInPercentage,
    required this.performanceScore,
  });

  final DateTime reportDate;
  final int totalEmployees;
  final int presentCount;
  final int absentCount;
  final int lateCheckInCount;

  /// Employees who checked in today ÷ roster size.
  final double attendancePercentage;

  /// Employees with no check-in today ÷ roster size.
  final double absentPercentage;

  /// Late check-ins ÷ present today (0 when nobody is present).
  final double lateCheckInPercentage;

  /// Composite 0–100 score (attendance weighted by punctuality).
  final double performanceScore;

  int get presentPercentage => attendancePercentage.round();

  @override
  List<Object?> get props => [
        reportDate,
        totalEmployees,
        presentCount,
        absentCount,
        lateCheckInCount,
        attendancePercentage,
        absentPercentage,
        lateCheckInPercentage,
        performanceScore,
      ];
}
