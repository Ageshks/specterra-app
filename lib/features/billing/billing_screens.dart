import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/action_widgets.dart';

const _categories = <String, String>{
  'DELIVERY': 'Delivery',
  'TRANSPORTATION': 'Transportation',
  'MATERIAL': 'Additional material',
  'SPARE_PARTS': 'Spare parts',
  'OTHER_EXPENSE': 'Other expense',
  'DISCOUNT': 'Discount',
};

String _money(double value) => '₹${value.toStringAsFixed(2)}';

Future<void> _previewReceipt(BuildContext context, String url) =>
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Receipt preview is unavailable.'),
            ),
          ),
        ),
      ),
    );

class BillingEditorScreen extends StatefulWidget {
  const BillingEditorScreen({super.key, required this.job});

  final WorkJob job;

  @override
  State<BillingEditorScreen> createState() => _BillingEditorScreenState();
}

class _BillingEditorScreenState extends State<BillingEditorScreen> {
  final _picker = ImagePicker();
  final _lines = <_BillingDraftLine>[];
  BillingInvoice? _invoice;
  bool _loading = true;
  bool _saving = false;
  bool _canAddCharges = true;
  bool _hasLocalChanges = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lines.add(_BillingDraftLine());
    _load();
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addLine([BillingLineItem? item]) {
    setState(() {
      _lines.add(_BillingDraftLine(item: item));
      _hasLocalChanges = true;
    });
  }

  Future<void> _load() async {
    final workOrderId = widget.job.workOrderId;
    if (workOrderId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'The work order ID is missing. Refresh the job and try again.';
      });
      return;
    }
    try {
      final repository = AppScope.read(context).repository;
      if (repository.role == 'MANAGER') {
        try {
          final config = await repository.fetchBillingConfig();
          _canAddCharges = config['managerCanAddCharges'] == true;
        } on ApiException catch (error) {
          if (error.statusCode == 403) _canAddCharges = false;
        }
      }
      final rows = await repository.fetchBillings(workOrderId: workOrderId);
      if (!mounted) return;
      if (rows.isNotEmpty) {
        final invoice = rows.first;
        setState(() {
          _invoice = invoice;
          for (final line in _lines) {
            line.dispose();
          }
          _lines
            ..clear()
            ..addAll(
              invoice.items.map((item) => _BillingDraftLine(item: item)),
            );
          if (_lines.isEmpty) _lines.add(_BillingDraftLine());
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  double get _chargeTotal => _lines.fold<double>(0, (sum, line) {
    final quantity = double.tryParse(line.quantity.text) ?? 0;
    final price = double.tryParse(line.unitPrice.text) ?? 0;
    final amount = quantity * price;
    return sum + (line.category == 'DISCOUNT' ? -amount : amount);
  });

  List<Map<String, dynamic>>? _itemsForSave() {
    final result = <Map<String, dynamic>>[];
    for (final line in _lines) {
      final description = line.description.text.trim();
      final quantity = double.tryParse(line.quantity.text.trim());
      final unitPrice = double.tryParse(line.unitPrice.text.trim());
      final empty =
          description.isEmpty &&
          (unitPrice == null || unitPrice == 0) &&
          line.receipt == null;
      if (empty) continue;
      if (description.isEmpty ||
          quantity == null ||
          quantity <= 0 ||
          unitPrice == null ||
          unitPrice < 0) {
        setState(() => line.showError = true);
        return null;
      }
      result.add({
        'category': line.category,
        'description': description,
        'quantity': quantity,
        'unitPrice': unitPrice,
      });
    }
    return result;
  }

  Future<BillingInvoice?> _persist() async {
    final items = _itemsForSave();
    if (items == null) return null;
    final repository = AppScope.read(context).repository;
    final existing = _invoice;
    final itemsChanged = existing != null && !_matchesInvoiceItems(existing);
    if (itemsChanged &&
        _lines.any((line) => line.hasUploadedReceipt && line.receipt == null)) {
      setState(() {
        _error =
            'Charge items changed. Reattach receipts to the existing items before saving so they stay on the bill.';
      });
      return null;
    }
    final invoice = existing == null
        ? await repository.createBilling(
            workOrderId: widget.job.workOrderId,
            items: items,
          )
        : itemsChanged
        ? await repository.updateBilling(id: existing.id, items: items)
        : existing;
    final populated = _lines
        .where((line) => line.description.text.trim().isNotEmpty)
        .toList();
    for (var i = 0; i < populated.length && i < invoice.items.length; i++) {
      final receipt = populated[i].receipt;
      if (receipt == null) continue;
      await repository.uploadBillingReceipt(
        invoiceId: invoice.id,
        invoiceItemId: invoice.items[i].id,
        bytes: await receipt.readAsBytes(),
        fileName: receipt.name,
      );
      populated[i]
        ..receipt = null
        ..hasUploadedReceipt = true;
    }
    _invoice = await repository.fetchBilling(invoice.id);
    return _invoice;
  }

  bool _matchesInvoiceItems(BillingInvoice invoice) {
    final populated = _lines
        .where((line) => line.description.text.trim().isNotEmpty)
        .toList();
    if (populated.length != invoice.items.length) return false;
    for (var i = 0; i < populated.length; i++) {
      final line = populated[i];
      final item = invoice.items[i];
      if (line.category != item.category ||
          line.description.text.trim() != item.description ||
          (double.tryParse(line.quantity.text) ?? 0) != item.quantity ||
          (double.tryParse(line.unitPrice.text) ?? 0) != item.unitPrice) {
        return false;
      }
    }
    return true;
  }

  Future<void> _save({required bool submit}) async {
    if (_saving) return;
    final repository = AppScope.read(context).repository;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final invoice = await _persist();
      if (invoice == null) return;
      final result = submit
          ? await repository.submitBilling(invoice.id)
          : invoice;
      if (!mounted) return;
      setState(() {
        _invoice = result;
        _hasLocalChanges = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            submit ? 'Billing submitted for approval.' : 'Draft saved.',
          ),
        ),
      );
      if (submit) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _saving = false;
      });
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  Future<void> _pickReceipt(_BillingDraftLine line) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take receipt photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (image != null && mounted) setState(() => line.receipt = image);
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final canEdit = (invoice == null || invoice.canEdit) && _canAddCharges;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          invoice == null ? 'Add Service Charges' : 'Service Billing',
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          14,
          AppTheme.gutter,
          28,
        ),
        children: [
          if (_error != null) ...[
            InfoCallout(message: _error!, tone: CalloutTone.warning),
            const SizedBox(height: 12),
          ],
          if (!_canAddCharges) ...[
            const InfoCallout(
              message:
                  'Your company billing settings do not allow managers to add charges.',
              tone: CalloutTone.warning,
            ),
            const SizedBox(height: 12),
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryLine(
                  label: 'Work order',
                  value: widget.job.workOrderId,
                ),
                _SummaryLine(label: 'Customer', value: widget.job.customerName),
                _SummaryLine(label: 'Service', value: widget.job.serviceType),
                _SummaryLine(
                  label: 'Base service price',
                  value: _money(
                    invoice?.baseServicePrice ?? widget.job.baseServiceAmount,
                  ),
                ),
                if (invoice != null) ...[
                  const Divider(height: 24),
                  _StatusPill(status: invoice.status),
                  if (invoice.rejectionReason?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Rejection remarks: ${invoice.rejectionReason}',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionHeader(
            title: 'Additional charges',
            trailing: canEdit
                ? TextButton.icon(
                    onPressed: () => _addLine(),
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Add item'),
                  )
                : null,
          ),
          ...List.generate(_lines.length, (index) {
            final line = _lines[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: line.category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: _categories.entries
                                .map(
                                  (entry) => DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  ),
                                )
                                .toList(),
                            onChanged: canEdit
                                ? (value) => setState(() {
                                    line.category = value ?? 'OTHER_EXPENSE';
                                    _hasLocalChanges = true;
                                  })
                                : null,
                          ),
                        ),
                        if (canEdit && _lines.length > 1)
                          IconButton(
                            tooltip: 'Remove item',
                            onPressed: () => setState(() {
                              _lines.removeAt(index).dispose();
                              _hasLocalChanges = true;
                            }),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.danger,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: line.description,
                      enabled: canEdit,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'What was purchased or delivered?',
                        errorText:
                            line.showError &&
                                line.description.text.trim().isEmpty
                            ? 'Enter a description'
                            : null,
                      ),
                      onChanged: (_) => setState(() => _hasLocalChanges = true),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: line.quantity,
                            enabled: canEdit,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Quantity',
                              errorText:
                                  line.showError &&
                                      (double.tryParse(line.quantity.text) ??
                                              0) <=
                                          0
                                  ? 'Required'
                                  : null,
                            ),
                            onChanged: (_) =>
                                setState(() => _hasLocalChanges = true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: line.unitPrice,
                            enabled: canEdit,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Unit price (₹)',
                              errorText:
                                  line.showError &&
                                      (double.tryParse(line.unitPrice.text) ??
                                              -1) <
                                          0
                                  ? 'Required'
                                  : null,
                            ),
                            onChanged: (_) =>
                                setState(() => _hasLocalChanges = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Line total  ${_money((double.tryParse(line.quantity.text) ?? 0) * (double.tryParse(line.unitPrice.text) ?? 0))}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: canEdit ? () => _pickReceipt(line) : null,
                          icon: const Icon(Icons.attach_file_rounded, size: 17),
                          label: Text(
                            line.receipt?.name ??
                                (line.hasUploadedReceipt
                                    ? 'Receipt uploaded'
                                    : 'Attach receipt'),
                          ),
                        ),
                      ],
                    ),
                    if (line.receipt != null)
                      Text(
                        'Selected: ${line.receipt!.name}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          _CalculationPreview(
            invoice: invoice,
            base: widget.job.baseServiceAmount,
            charges: _chargeTotal,
            gstRate: widget.job.gstRate,
            gstInclusive: widget.job.gstInclusive,
            hasLocalChanges: _hasLocalChanges,
          ),
          if (canEdit) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _save(submit: false),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save Draft'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(submit: true),
              icon: const Icon(Icons.send_rounded),
              label: Text(_saving ? 'Saving…' : 'Submit for Approval'),
            ),
          ],
        ],
      ),
    );
  }
}

class _BillingDraftLine {
  _BillingDraftLine({BillingLineItem? item})
    : category = item?.category ?? 'DELIVERY',
      description = TextEditingController(text: item?.description ?? ''),
      quantity = TextEditingController(text: item?.quantity.toString() ?? '1'),
      unitPrice = TextEditingController(text: item?.unitPrice.toString() ?? ''),
      hasUploadedReceipt = item?.attachments.isNotEmpty ?? false;

  String category;
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  bool hasUploadedReceipt;
  XFile? receipt;
  bool showError = false;

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}

class _CalculationPreview extends StatelessWidget {
  const _CalculationPreview({
    required this.invoice,
    required this.base,
    required this.charges,
    required this.gstRate,
    required this.gstInclusive,
    required this.hasLocalChanges,
  });

  final BillingInvoice? invoice;
  final double base;
  final double charges;
  final double? gstRate;
  final bool gstInclusive;
  final bool hasLocalChanges;

  @override
  Widget build(BuildContext context) {
    final current = invoice;
    final knownRate = current?.gstRate ?? gstRate;
    final useServerValues = current != null && !hasLocalChanges;
    final basePrice = current != null && current.baseServicePrice > 0
        ? current.baseServicePrice
        : base;
    final subtotal = basePrice + charges;
    final inclusive = current?.taxInclusive ?? gstInclusive;
    final taxable = useServerValues
        ? current.taxableAmount
        : (knownRate == null
              ? subtotal
              : inclusive
              ? subtotal / (1 + knownRate / 100)
              : subtotal);
    final tax = useServerValues
        ? current.gstAmount
        : (knownRate == null
              ? 0.0
              : inclusive
              ? subtotal - taxable
              : taxable * knownRate / 100);
    final finalAmount = useServerValues
        ? current.finalAmount
        : (inclusive ? subtotal : subtotal + tax);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calculation preview',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _SummaryLine(label: 'Additional charges', value: _money(charges)),
          _SummaryLine(label: 'Taxable amount', value: _money(taxable)),
          if (knownRate != null)
            _SummaryLine(
              label: 'GST (${knownRate.toStringAsFixed(2)}%)',
              value: _money(tax),
            ),
          if (useServerValues && current.cgstAmount > 0)
            _SummaryLine(label: 'CGST', value: _money(current.cgstAmount)),
          if (useServerValues && current.sgstAmount > 0)
            _SummaryLine(label: 'SGST', value: _money(current.sgstAmount)),
          if (useServerValues && current.igstAmount > 0)
            _SummaryLine(label: 'IGST', value: _money(current.igstAmount)),
          const Divider(height: 20),
          _SummaryLine(
            label: 'Final payable',
            value: _money(finalAmount),
            strong: true,
          ),
          if (current == null && knownRate == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'GST rate is configured per service. The backend will calculate and return the final tax amounts when you save.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          if (current != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Amounts shown are calculated by the billing server.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class BillingHistoryScreen extends StatefulWidget {
  const BillingHistoryScreen({super.key});

  @override
  State<BillingHistoryScreen> createState() => _BillingHistoryScreenState();
}

class _BillingHistoryScreenState extends State<BillingHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<BillingInvoice> _invoices = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invoices = await AppScope.read(context).repository.fetchBillings();
      if (mounted) {
        setState(() {
          _invoices = invoices;
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Billing History')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? ErrorState(message: _error!, onRetry: _load)
        : RefreshIndicator(
            onRefresh: _load,
            child: _invoices.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100),
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No billing yet',
                        message:
                            'Service charges and invoice status will appear here.',
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.gutter),
                    itemCount: _invoices.length,
                    itemBuilder: (context, index) {
                      final invoice = _invoices[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  BillingDetailsScreen(invoice: invoice),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      invoice.workOrderNumber.isEmpty
                                          ? invoice.workOrderId
                                          : invoice.workOrderNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  _StatusPill(status: invoice.status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${invoice.customerName} • ${invoice.serviceName}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _SummaryLine(
                                label: 'Additional charges',
                                value: _money(
                                  invoice.items.fold<double>(
                                    0,
                                    (sum, item) => sum + item.amount,
                                  ),
                                ),
                              ),
                              _SummaryLine(
                                label: 'GST',
                                value: _money(invoice.gstAmount),
                              ),
                              _SummaryLine(
                                label: 'Final amount',
                                value: _money(invoice.finalAmount),
                                strong: true,
                              ),
                              if (invoice.createdBy.isNotEmpty)
                                Text(
                                  'Submitted by ${invoice.createdBy}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              if (invoice.submittedAt != null)
                                Text(
                                  'Submitted ${Formatters.dateTime(invoice.submittedAt!)}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              if (invoice.approvedBy.isNotEmpty)
                                Text(
                                  'Approved by ${invoice.approvedBy}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              if (invoice.rejectionReason?.isNotEmpty == true)
                                Text(
                                  'Remarks: ${invoice.rejectionReason}',
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
  );
}

class BillingDetailsScreen extends StatefulWidget {
  const BillingDetailsScreen({super.key, required this.invoice});
  final BillingInvoice invoice;

  @override
  State<BillingDetailsScreen> createState() => _BillingDetailsScreenState();
}

class _BillingDetailsScreenState extends State<BillingDetailsScreen> {
  late BillingInvoice _invoice = widget.invoice;
  bool _loading = false;

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final updated = await AppScope.read(
        context,
      ).repository.fetchBilling(_invoice.id);
      if (mounted) {
        setState(() {
          _invoice = updated;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(bool approve) async {
    final remarks = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Approve billing?' : 'Reject billing?'),
        content: TextField(
          controller: remarks,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: approve ? 'Remarks (optional)' : 'Rejection remarks',
            hintText: approve ? 'Add a note' : 'Explain what needs correction',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = remarks.text.trim();
              if (!approve && value.isEmpty) return;
              Navigator.pop(context, value);
            },
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    remarks.dispose();
    if (reason == null || !mounted) return;
    setState(() => _loading = true);
    try {
      final updated = await AppScope.read(context).repository.decideBilling(
        id: _invoice.id,
        approve: approve,
        remarks: reason,
      );
      if (mounted) {
        setState(() {
          _invoice = updated;
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).repository;
    final isOwnSubmission =
        _invoice.createdById.isNotEmpty &&
        _invoice.createdById == repository.currentEmployee?.id;
    final canApprove =
        repository.isSupervisor &&
        _invoice.status == 'PENDING_APPROVAL' &&
        !isOwnSubmission;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Billing Details'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.gutter),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _invoice.workOrderNumber.isEmpty
                              ? _invoice.workOrderId
                              : _invoice.workOrderNumber,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _StatusPill(status: _invoice.status),
                    ],
                  ),
                  _SummaryLine(label: 'Customer', value: _invoice.customerName),
                  _SummaryLine(label: 'Service', value: _invoice.serviceName),
                  _SummaryLine(
                    label: 'Base service price',
                    value: _money(_invoice.baseServicePrice),
                  ),
                  if (_invoice.createdBy.isNotEmpty)
                    _SummaryLine(
                      label: 'Submitted by',
                      value: _invoice.createdBy,
                    ),
                  if (_invoice.submittedAt != null)
                    _SummaryLine(
                      label: 'Submitted',
                      value: Formatters.dateTime(_invoice.submittedAt!),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const SectionHeader(title: 'Additional charges'),
            ..._invoice.items.map(
              (item) => AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _categories[item.category] ??
                          item.category.replaceAll('_', ' '),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      item.description,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    _SummaryLine(
                      label: '${item.quantity} × ${_money(item.unitPrice)}',
                      value: _money(item.amount),
                    ),
                    if (item.attachments.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        children: item.attachments
                            .map(
                              (file) => TextButton.icon(
                                onPressed: () =>
                                    _previewReceipt(context, file.url),
                                icon: const Icon(Icons.image_outlined),
                                label: const Text('Preview receipt'),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
            AppCard(
              child: Column(
                children: [
                  _SummaryLine(
                    label: 'Taxable amount',
                    value: _money(_invoice.taxableAmount),
                  ),
                  _SummaryLine(
                    label: 'GST (${_invoice.gstRate.toStringAsFixed(2)}%)',
                    value: _money(_invoice.gstAmount),
                  ),
                  _SummaryLine(
                    label: 'CGST',
                    value: _money(_invoice.cgstAmount),
                  ),
                  _SummaryLine(
                    label: 'SGST',
                    value: _money(_invoice.sgstAmount),
                  ),
                  _SummaryLine(
                    label: 'IGST',
                    value: _money(_invoice.igstAmount),
                  ),
                  const Divider(height: 20),
                  _SummaryLine(
                    label: 'Final payable',
                    value: _money(_invoice.finalAmount),
                    strong: true,
                  ),
                  if (_invoice.approvedBy.isNotEmpty)
                    _SummaryLine(
                      label: 'Approved by',
                      value: _invoice.approvedBy,
                    ),
                  if (_invoice.rejectionReason?.isNotEmpty == true)
                    _SummaryLine(
                      label: 'Rejection remarks',
                      value: _invoice.rejectionReason!,
                    ),
                ],
              ),
            ),
            if (_invoice.attachments.isNotEmpty) ...[
              const SectionHeader(title: 'Receipts'),
              ..._invoice.attachments.map(
                (item) => TextButton.icon(
                  onPressed: () => _previewReceipt(context, item.url),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Preview receipt'),
                ),
              ),
            ],
            if (canApprove) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => _decide(false),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading ? null : () => _decide(true),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
            if (repository.isSupervisor &&
                _invoice.status == 'PENDING_APPROVAL' &&
                isOwnSubmission)
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: InfoCallout(
                  message:
                      'You submitted this bill. Another authorized approver must review it.',
                  tone: CalloutTone.warning,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BillingApprovalScreen extends StatefulWidget {
  const BillingApprovalScreen({super.key});

  @override
  State<BillingApprovalScreen> createState() => _BillingApprovalScreenState();
}

class _BillingApprovalScreenState extends State<BillingApprovalScreen> {
  bool _loading = true;
  String? _error;
  List<BillingInvoice> _pending = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await AppScope.read(
        context,
      ).repository.fetchPendingBillings();
      if (mounted) {
        setState(() {
          _pending = values;
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Billing Approvals')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? ErrorState(message: _error!, onRetry: _load)
        : RefreshIndicator(
            onRefresh: _load,
            child: _pending.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100),
                      EmptyState(
                        icon: Icons.fact_check_outlined,
                        title: 'No pending bills',
                        message:
                            'Submitted billing waiting for your decision will appear here.',
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.gutter),
                    itemCount: _pending.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        onTap: () => Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder: (_) => BillingDetailsScreen(
                                  invoice: _pending[index],
                                ),
                              ),
                            )
                            .then((_) => _load()),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _pending[index].workOrderNumber.isEmpty
                                        ? _pending[index].workOrderId
                                        : _pending[index].workOrderNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const _StatusPill(status: 'PENDING_APPROVAL'),
                              ],
                            ),
                            Text(
                              '${_pending[index].customerName} • ${_pending[index].serviceName}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            _SummaryLine(
                              label: 'Base price',
                              value: _money(_pending[index].baseServicePrice),
                            ),
                            _SummaryLine(
                              label: 'Additional charges',
                              value: _money(
                                _pending[index].items.fold<double>(
                                  0,
                                  (sum, item) => sum + item.amount,
                                ),
                              ),
                            ),
                            _SummaryLine(
                              label: 'GST',
                              value: _money(_pending[index].gstAmount),
                            ),
                            _SummaryLine(
                              label: 'Final amount',
                              value: _money(_pending[index].finalAmount),
                              strong: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
  );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.strong = false,
  });
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong ? AppColors.ink : AppColors.muted,
              fontSize: 12,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 12,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'APPROVED' || 'FINALIZED' => AppColors.success,
      'REJECTED' => AppColors.danger,
      'PENDING_APPROVAL' => AppColors.warning,
      _ => AppColors.info,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
