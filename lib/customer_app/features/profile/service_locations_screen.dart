import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/customer.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';

/// Customer's saved service locations with add, edit, delete and default actions.
class ServiceLocationsScreen extends StatelessWidget {
  const ServiceLocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final addresses = CustomerScope.of(context).data.addresses;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Locations'),
        actions: [
          IconButton(
            tooltip: 'Add location',
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add_location_alt_outlined),
          ),
        ],
      ),
      body: addresses.isEmpty
          ? EmptyState(
              icon: Icons.location_off_outlined,
              title: 'No saved locations',
              message: 'Add a service location to make future bookings faster.',
              actionLabel: 'Add Location',
              onAction: () => _edit(context),
            )
          : ListView(
              padding: const EdgeInsets.all(AppTheme.gutter),
              children: [
                const Text('Choose a location while booking. Your default location is selected first.'),
                const SizedBox(height: 16),
                ...addresses.map((address) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(address.icon),
                      const SizedBox(width: 10),
                      Expanded(child: Text(address.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                      if (address.isDefault) const Chip(label: Text('Default')),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _edit(context, address: address);
                          if (value == 'default') CustomerScope.of(context).setDefaultServiceLocation(address.id);
                          if (value == 'delete') _delete(context, address);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit Location')),
                          if (!address.isDefault) const PopupMenuItem(value: 'default', child: Text('Set as Default')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete Location')),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(address.lines),
                  ])),
                )),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add New Location'),
                )),
              ],
            ),
    );
  }

  static Future<void> _edit(BuildContext context, {ServiceAddress? address}) =>
      showDialog<void>(
        context: context,
        // Keep the dialog on the customer navigator (inside CustomerScope) so
        // the editor can resolve CustomerScope.of(context) when saving.
        useRootNavigator: false,
        builder: (_) => _LocationEditor(address: address),
      );

  static Future<void> _delete(BuildContext context, ServiceAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete service location?'),
        content: Text('Remove ${address.label} from your saved locations?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await CustomerScope.of(context).deleteServiceLocation(address.id);
    }
  }
}

class _LocationEditor extends StatefulWidget {
  const _LocationEditor({this.address});
  final ServiceAddress? address;
  @override
  State<_LocationEditor> createState() => _LocationEditorState();
}

class _LocationEditorState extends State<_LocationEditor> {
  late final _label = TextEditingController(text: widget.address?.label);
  late final _lines = TextEditingController(text: widget.address?.lines);
  late final _city = TextEditingController(text: widget.address?.city);
  late final _state = TextEditingController(text: widget.address?.state);
  late final _pincode = TextEditingController(text: widget.address?.pincode);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    _lines.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_label.text.trim().isEmpty || _lines.text.trim().isEmpty ||
        _city.text.trim().isEmpty || _state.text.trim().isEmpty ||
        _pincode.text.trim().length != 6) {
      setState(() => _error = 'Enter location name, address, city, state and a 6-digit pincode.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    await CustomerScope.of(context).saveServiceLocation(
      id: widget.address?.id,
      label: _label.text,
      address: _lines.text,
      city: _city.text,
      state: _state.text,
      pincode: _pincode.text,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.address == null ? 'Add Location' : 'Edit Location'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _label, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Location Name')),
      const SizedBox(height: 10),
       TextField(controller: _lines, minLines: 2, maxLines: 4, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Street Address')),
       const SizedBox(height: 10),
       TextField(controller: _city, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'City')),
       const SizedBox(height: 10),
       TextField(controller: _state, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'State')),
       const SizedBox(height: 10),
       TextField(controller: _pincode, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pincode (6 digits)')),
      if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
    ]),
    actions: [
      TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
    ],
  );
}
