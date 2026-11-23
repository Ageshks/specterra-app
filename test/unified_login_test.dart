import 'package:flutter_test/flutter_test.dart';
import 'package:specterra_staff/features/auth/unified_login_screen.dart';

/// The single login page routes by identifier and registers customers only.
void main() {
  group('unified login role detection', () {
    test('SPT employee IDs route to staff', () {
      expect(UnifiedLoginScreen.isStaffIdentifier('SPT-1042'), isTrue);
      expect(UnifiedLoginScreen.isStaffIdentifier('spt-0201'), isTrue);
      expect(UnifiedLoginScreen.isStaffIdentifier('SPT 1042'), isTrue);
      expect(UnifiedLoginScreen.isStaffIdentifier('  SPT-1042  '), isTrue);
    });

    test('emails and phone numbers route to customer', () {
      expect(
        UnifiedLoginScreen.isStaffIdentifier('user@example.com'),
        isFalse,
      );
      expect(UnifiedLoginScreen.isStaffIdentifier('9876543210'), isFalse);
      expect(
        UnifiedLoginScreen.isStaffIdentifier('+91 98765 43210'),
        isFalse,
      );
      expect(UnifiedLoginScreen.isStaffIdentifier(''), isFalse);
    });
  });
}
