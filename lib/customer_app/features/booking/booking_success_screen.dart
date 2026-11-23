import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/booking.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../home/shell_scope.dart';
import '../tracking/tracking_screen.dart';
import '../auth/signup_screen.dart';

/// Celebration screen shown once a booking is confirmed.
class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shell = ShellScope.maybeOf(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gutter),
          child: Column(
            children: [
              const Spacer(),
              const SuccessState(
                title: 'Service Request Submitted Successfully',
                message:
                    'Your service request is in. We will notify you when it is confirmed.',
                icon: Icons.check_circle_rounded,
              ),
              const SizedBox(height: 20),
              AppCard(
                child: Column(
                  children: [
                    InfoRow(
                      icon: Icons.confirmation_number_outlined,
                      text: booking.id,
                      bold: true,
                    ),
                    InfoRow(
                      icon: Icons.water_drop_outlined,
                      text: booking.serviceName,
                    ),
                    InfoRow(
                      icon: Icons.event_rounded,
                      text: Formatters.dateTime(booking.scheduledAt),
                    ),
                    InfoRow(
                      icon: Icons.location_on_outlined,
                      text: booking.address,
                      maxLines: 2,
                    ),
                    for (final product in booking.bookingProducts)
                      InfoRow(
                        icon: Icons.shopping_bag_outlined,
                        text:
                            '${product.name} × ${product.quantity} · ${Formatters.rupees(product.lineTotal)}',
                        maxLines: 2,
                      ),
                    InfoRow(
                      icon: Icons.payments_outlined,
                      text: Formatters.rupees(booking.amount),
                      bold: true,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (shell == null)
                FilledButton(
                  onPressed: () => Navigator.of(context).popUntil(
                    (route) => route.isFirst,
                  ),
                  child: const Text('Back to Services'),
                )
              else ...[
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    shell.goToTab(2);
                  },
                  child: const Text('View My Bookings'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => TrackingScreen(bookingId: booking.id),
                      ),
                    );
                  },
                  child: const Text('Track technician live'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => SignUpScreen()),
                  ),
                  child: const Text('Create an account (optional)'),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'We will send a reminder 1 hour before the visit.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
