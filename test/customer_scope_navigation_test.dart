import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:specterra_staff/customer_app/features/booking/booking_screen.dart';
import 'package:specterra_staff/customer_app/state/app_state.dart';
import 'package:specterra_staff/features/auth/unified_login_screen.dart';
import 'package:specterra_staff/features/unified_home_screen.dart';

/// Routes pushed from the customer shell (booking wizard, service details,
/// tracking, ...) must build *inside* CustomerScope. CustomerSessionHost keeps
/// the scope above a nested navigator for exactly this reason; a push on the
/// root navigator used to build outside the scope and crash with
/// "CustomerScope.of() called outside of CustomerScope" (branded error screen).
///
/// That nested navigator must also receive the system back button / gesture:
/// the OS only asks the root navigator, which used to bubble (first route) and
/// close the app instead of popping the booking wizard. The AppBar's back
/// button, which pops the nearest navigator, always worked.
void main() {
  testWidgets(
    'pushed booking wizard stays inside CustomerScope (Book Now)',
    (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerSessionHost(controller: controller, keepAlive: true),
        ),
      );
      await tester.pumpAndSettle();

      // "Book Service" quick action on the signed-in home tab.
      await tester.tap(find.byIcon(Icons.add_task_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(BookingScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'system back pops the booking wizard instead of closing the app',
    (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerSessionHost(controller: controller, keepAlive: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_task_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(BookingScreen), findsOneWidget);

      // The engine delivers `popRoute` on the navigation channel; the binding
      // consults the root navigator first and then the observers. It must be
      // handled by popping the nested wizard, not closed via
      // SystemNavigator.pop().
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.byType(BookingScreen), findsNothing);
      expect(find.byIcon(Icons.add_task_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AppBar back button on the booking wizard matches the system back',
    (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerSessionHost(controller: controller, keepAlive: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_task_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(BookingScreen), findsOneWidget);

      // BookingScreen leads with a custom back arrow on step zero.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(BookingScreen), findsNothing);
      expect(find.byIcon(Icons.add_task_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'system back at the customer shell root is left to close the app',
    (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerSessionHost(controller: controller, keepAlive: true),
        ),
      );
      await tester.pumpAndSettle();

      // Nothing pushed on the nested navigator: back must not be swallowed,
      // the OS gets to close the app as usual from a first route.
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isFalse);
      expect(find.byIcon(Icons.add_task_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'guest: system back walks wizard -> guest home -> welcome',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UnifiedHomeScreen()));
      await tester.pumpAndSettle();

      // GuestLaunch is pushed *above* the welcome screen, so the root
      // navigator could pop - but back inside the wizard must stay within the
      // guest host instead of jumping straight to the welcome screen.
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_task_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(BookingScreen), findsOneWidget);

      var handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.byType(BookingScreen), findsNothing);
      expect(find.text('My Bookings'), findsWidgets); // still inside guest host
      expect(find.text('Continue as Guest'), findsNothing);

      // With the wizard gone the guest host is poppable on the root navigator.
      handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.text('Continue as Guest'), findsOneWidget); // welcome again
    },
  );
}
