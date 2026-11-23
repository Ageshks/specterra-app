import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import 'tracking_screen.dart';

/// Public booking lookup. Requires both fields before revealing a timeline.
class GuestTrackingLookupScreen extends StatefulWidget {
  const GuestTrackingLookupScreen({super.key});

  @override
  State<GuestTrackingLookupScreen> createState() => _GuestTrackingLookupScreenState();
}

class _GuestTrackingLookupScreenState extends State<GuestTrackingLookupScreen> {
  final _id = TextEditingController();
  final _mobile = TextEditingController();
  String? _error;

  @override
  void dispose() { _id.dispose(); _mobile.dispose(); super.dispose(); }

  void _track() {
    final id = _id.text.trim();
    final mobile = _mobile.text.replaceAll(RegExp(r'\D'), '');
    if (id.isEmpty || mobile.length < 10) {
      setState(() => _error = 'Enter your booking ID and 10 digit mobile number.');
      return;
    }
    final matches = CustomerScope.of(context).data.bookings.where(
      (booking) => booking.id.toLowerCase() == id.toLowerCase(),
    );
    if (matches.isEmpty || matches.first.contactNumber.replaceAll(RegExp(r'\D'), '') != mobile) {
      setState(() => _error = 'We could not find a booking with those details.');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TrackingScreen(bookingId: matches.first.id)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Track Booking')),
    body: ListView(
      padding: const EdgeInsets.all(AppTheme.gutter),
      children: [
        const Text('Enter the details used when you requested service.', style: TextStyle(height: 1.45)),
        const SizedBox(height: 18),
        TextField(controller: _id, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Booking ID', hintText: 'SPT-2026-00125')),
        const SizedBox(height: 12),
        TextField(controller: _mobile, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number')),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _track, icon: const Icon(Icons.track_changes_rounded), label: const Text('Track Booking'))),
      ],
    ),
  );
}
