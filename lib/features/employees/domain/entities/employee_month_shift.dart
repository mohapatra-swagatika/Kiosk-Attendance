import 'package:equatable/equatable.dart';

/// One scheduled shift from snapshot `currentMonthShifts`.
class EmployeeMonthShift extends Equatable {
  const EmployeeMonthShift({
    required this.date,
    required this.shiftName,
    required this.shiftCode,
    this.shiftId,
  });

  final String date;
  final String shiftName;
  final String shiftCode;
  final int? shiftId;

  @override
  List<Object?> get props => [date, shiftName, shiftCode, shiftId];
}
