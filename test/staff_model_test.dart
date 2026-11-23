import 'package:flutter_test/flutter_test.dart';
import 'package:specterra_staff/core/utils/formatters.dart';
import 'package:specterra_staff/data/models/enums.dart';
import 'package:specterra_staff/data/models/models.dart';

void main() {
  group('Staff time formatting', () {
    test('formats UTC timestamps in India Standard Time', () {
      expect(Formatters.time(DateTime.utc(2026, 11, 10, 0, 0)), '5:30 AM');
      expect(
        Formatters.dateTime(DateTime.utc(2026, 11, 10, 20, 0)),
        '11 Nov, 2026, 1:30 AM',
      );
    });
  });

  group('Work assignment parsing', () {
    test('keeps assignment and work order IDs distinct', () {
      final job = WorkJob.fromJson({
        'id': 'assignment-42',
        'status': 'ASSIGNED',
        'workOrder': {
          'id': 'order-17',
          'customer': {'name': 'Maya Patel', 'phone': '+919876543210'},
          'serviceLocation': {
            'address': '10 Lake Road',
            'latitude': 22.5726,
            'longitude': 88.3639,
          },
          'scheduledAt': '2026-11-10T08:30:00.000Z',
        },
      });

      expect(job.id, 'assignment-42');
      expect(job.assignmentId, 'assignment-42');
      expect(job.workOrderId, 'order-17');
      expect(job.customerName, 'Maya Patel');
      expect(job.contactNumber, '+919876543210');
      expect(job.latitude, 22.5726);
      expect(job.longitude, 88.3639);
    });

    test('reads customer name from the linked user on an assignment', () {
      final job = WorkJob.fromJson({
        'id': 'assignment-43',
        'status': 'ASSIGNED',
        'workOrder': {
          'id': 'order-18',
          'customer': {
            'user': {'firstName': 'Asha', 'lastName': 'Rao'},
          },
        },
      });

      expect(job.customerName, 'Asha Rao');
    });

    test('reads customer name from the linked booking customer', () {
      final job = WorkJob.fromJson({
        'id': 'assignment-44',
        'status': 'ASSIGNED',
        'workOrder': {
          'id': 'order-19',
          'booking': {
            'customer': {
              'user': {'firstName': 'Ravi', 'lastName': 'Kumar'},
            },
          },
        },
      });

      expect(job.customerName, 'Ravi Kumar');
    });

    test('reads the customer phone from the linked booking user', () {
      final job = WorkJob.fromJson({
        'id': 'assignment-45',
        'status': 'ASSIGNED',
        'workOrder': {
          'id': 'order-20',
          'booking': {
            'customer': {
              'user': {'phoneNumber': '+1 (415) 555-0132'},
            },
          },
        },
      });

      expect(job.contactNumber, '+1 (415) 555-0132');
    });

    test('reads a phone number nested in customer contact details', () {
      final job = WorkJob.fromJson({
        'id': 'assignment-46',
        'status': 'ASSIGNED',
        'workOrder': {
          'id': 'order-21',
          'customer': {
            'contact': {'mobileNumber': '+91 98765 43210'},
          },
        },
      });

      expect(job.contactNumber, '+91 98765 43210');
    });
  });

  group('Transfer staff parsing', () {
    test('recognizes technician titles but excludes managers as assignees', () {
      final technician = StaffMember.fromJson({
        'id': 'tech-1',
        'name': 'Asha Rao',
        'designation': 'Technician',
        'availability': 'AVAILABLE',
      });
      final manager = StaffMember.fromJson({
        'id': 'manager-1',
        'name': 'Ravi Kumar',
        'designation': 'Branch Manager',
        'availability': 'AVAILABLE',
      });

      expect(technician.isSelectable, isTrue);
      expect(manager.isTransferEligible, isFalse);
      expect(manager.isSelectable, isFalse);
    });

    test('reads designation and employee id from nested staff payloads', () {
      final staff = StaffMember.fromJson({
        'id': 'user-1',
        'employee': {
          'id': 'employee-1',
          'designation': 'Field Technician',
          'user': {'firstName': 'Maya', 'lastName': 'Patel'},
        },
        'role': 'EMPLOYEE',
      });

      expect(staff.id, 'employee-1');
      expect(staff.name, 'Maya Patel');
      expect(staff.role, 'Field Technician');
      expect(staff.isSelectable, isTrue);
    });
  });

  group('Transfer request status', () {
    test('approved requests are no longer awaiting a manager decision', () {
      final request = TransferRequest.fromJson({
        'id': 'transfer-1',
        'status': 'APPROVED',
        'workOrderId': 'order-1',
        'requestedEmployeeId': 'technician-2',
      });

      expect(request.status, TransferStatus.transferApproved);
      expect(request.status.isPending, isFalse);
    });

    test('new transfer requests remain pending until reviewed', () {
      final request = TransferRequest.fromJson({
        'id': 'transfer-2',
        'status': 'TRANSFER_REQUESTED',
        'workOrderId': 'order-2',
      });

      expect(request.status, TransferStatus.transferRequested);
      expect(request.status.isPending, isTrue);
    });
  });

  group('Admin working calendar parsing', () {
    final calendar = WorkingCalendar.fromJson({
      'year': 2026,
      'startDate': '2026-01-01',
      'endDate': '2026-12-31',
      'workingWeekdays': [1, 2, 3, 4, 5],
      'exceptions': [
        {'date': '2026-01-26', 'title': 'Republic Day', 'type': 'HOLIDAY'},
        {
          'date': '2026-08-15',
          'title': 'Independence Day working day',
          'type': 'WORKING_DAY',
        },
        {
          'date': '2026-12-25',
          'title': 'Christmas celebration',
          'type': 'EVENT',
          'note': 'Office gathering',
        },
      ],
    });

    test('uses ISO weekday values for regular working days', () {
      expect(calendar.dayInfo(DateTime(2026, 11, 10)).isWorkingDay, isTrue);
      expect(calendar.dayInfo(DateTime(2026, 11, 8)).isWorkingDay, isFalse);
    });

    test('marks holidays as non-working days and keeps their title', () {
      final day = calendar.dayInfo(DateTime(2026, 1, 26));
      expect(day.isWorkingDay, isFalse);
      expect(day.exception?.title, 'Republic Day');
    });

    test('working-day exceptions take precedence over the weekday pattern', () {
      final day = calendar.dayInfo(DateTime(2026, 8, 15));
      expect(day.isWorkingDay, isTrue);
      expect(day.exception?.title, 'Independence Day working day');
    });

    test('events display without changing the weekday working status', () {
      final day = calendar.dayInfo(DateTime(2026, 12, 25));
      expect(day.isWorkingDay, isTrue);
      expect(day.exception?.type, 'EVENT');
      expect(day.exception?.note, 'Office gathering');
    });

    test('matches zero-padded date keys', () {
      expect(
        calendar.dayInfo(DateTime(2026, 1, 26)).exception?.date,
        '2026-01-26',
      );
    });
  });
}
