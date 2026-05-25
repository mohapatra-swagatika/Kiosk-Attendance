import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';

/// Shared demo roster for seed + server sync (10 employees).
class MockEmployeeRoster {
  MockEmployeeRoster._();

  static List<Employee> employees() => const [
        Employee(
          id: 'E-1001',
          name: 'Asha Kapoor',
          department: 'Engineering',
          imageUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Asha',
          pin: '4521',
          faceRegistered: false,
        ),
        Employee(
          id: 'E-1002',
          name: 'Marcus Lee',
          department: 'Operations',
          imageUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Marcus',
          pin: '7832',
          faceRegistered: false,
        ),
        Employee(
          id: 'E-1003',
          name: 'Nina Rossi',
          department: 'People',
          imageUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Nina',
          pin: '9014',
          faceRegistered: false,
        ),
        Employee(
          id: 'E-1004',
          name: 'James Ortiz',
          department: 'Finance',
          imageUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=James',
          pin: '3344',
          faceRegistered: false,
        ),
        Employee(
          id: 'E-1005',
          name: 'Priya Sharma',
          department: 'Engineering',
          imageUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Priya',
          pin: '5567',
          faceRegistered: false,
        ),
        Employee(
          id: 'E-1006',
          name: 'Daniel Kim',
          department: 'Sales',
          imageUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Daniel',
          pin: '6689',
          faceRegistered: false,
        ),
        Employee(
          id: 'E-1007',
          name: 'Sofia Martinez',
          department: 'Marketing',
          imageUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Sofia',
          pin: '7720',
          faceRegistered: false,
        ),
        Employee(
          id: 'E-1008',
          name: 'Oliver Chen',
          department: 'Support',
          imageUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Oliver',
          pin: '8812',
          faceRegistered: false,
        ),
        Employee(
          id: 'E-1009',
          name: 'Emma Wilson',
          department: 'HR',
          imageUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Emma',
          pin: '9934',
          faceRegistered: false,
        ),
        Employee(
          id: 'E-1010',
          name: 'Liam O\'Connor',
          department: 'Security',
          imageUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Liam',
          pin: '1045',
          faceRegistered: false,
        ),
      ];
}
