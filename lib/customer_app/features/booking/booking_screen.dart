import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/customer.dart';
import '../../data/models/product.dart';
import '../../data/models/water_service.dart';
import '../../state/app_state.dart';
import '../../widgets/booking_stepper.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/filter_widgets.dart';
import '../../widgets/loading_views.dart';
import '../../widgets/service_tile.dart';
import 'booking_success_screen.dart';

/// Four-step booking wizard: Service → Details → Products → Confirm.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, this.preselectedServiceId});

  final String? preselectedServiceId;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  static const List<String> _steps = <String>[
    'Service',
    'Details',
    'Products',
    'Confirm',
  ];

  final _notesController = TextEditingController();
  final _addressController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  int _currentStep = 0;
  String? _serviceId;
  ServiceAddress? _address;
  String _paymentMode = 'Pay after service';
  bool _isSubmitting = false;
  String _error = '';
  bool _addressInitialized = false;
  bool _guestMode = false;
  List<Product> _products = const <Product>[];
  final Map<String, int> _selectedProducts = <String, int>{};
  bool _isLoadingProducts = false;
  String? _productsError;
  String? _loadedCompanySlug;

  @override
  void initState() {
    super.initState();
    _serviceId = widget.preselectedServiceId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_addressInitialized) return;
    final addresses = CustomerScope.of(context).data.addresses;
    if (addresses.isNotEmpty) {
      _address = addresses.first;
      for (final address in addresses) {
        if (address.isDefault) _address = address;
      }
      _addressInitialized = true;
    }
    _guestMode = !CustomerScope.of(context).repository.api.hasToken;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _addressController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  WaterService? _resolveService(List<WaterService> services) {
    for (final service in services) {
      if (service.id == _serviceId) return service;
    }
    return null;
  }

  bool get _canContinue => switch (_currentStep) {
    0 => _serviceId != null,
    1 => (_address != null || _addressController.text.trim().isNotEmpty) &&
        _nameController.text.trim().isNotEmpty &&
        _phoneController.text.replaceAll(RegExp(r'\D'), '').length >= 10,
    2 => true,
    _ => true,
  };

  String get _validationMessage => switch (_currentStep) {
    0 => 'Select a service to continue',
    1 => 'Enter your name, mobile number and service address (any text works for guests)',
    2 => '',
    _ => '',
  };

  Future<void> _next() async {
    if (!_canContinue) {
      setState(() => _error = _validationMessage);
      return;
    }
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _error = '';
        _currentStep++;
      });
      if (_currentStep == 2) await _loadProducts();
      return;
    }
    await _confirmBooking();
  }

  Future<void> _loadProducts({bool retry = false}) async {
    final controller = CustomerScope.of(context);
    final companySlug = controller.customer?.companySlug?.trim();
    if (companySlug == null || companySlug.isEmpty) return;
    if (_isLoadingProducts ||
        (!retry && _loadedCompanySlug == companySlug)) {
      return;
    }

    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });
    try {
      final products = await controller.repository.fetchProducts(companySlug);
      if (!mounted) return;
      setState(() {
        _products = products;
        _loadedCompanySlug = companySlug;
      });
    } on DataFailure catch (error) {
      if (mounted) setState(() => _productsError = error.message);
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _changeProductQuantity(Product product, int change) {
    setState(() {
      final nextQuantity = (_selectedProducts[product.id] ?? 0) + change;
      if (nextQuantity <= 0) {
        _selectedProducts.remove(product.id);
      } else {
        _selectedProducts[product.id] = nextQuantity;
      }
    });
  }

  void _back() {
    if (_currentStep == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _currentStep--;
      _error = '';
    });
  }

  DateTime _resolveDateTime() {
    // Customers do not pick a slot; the backend assigns date/time when the
    // request is accepted. Send a neutral default placeholder.
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 10, 0);
  }

  Future<void> _confirmBooking() async {
    if (_isSubmitting) return;
    final controller = CustomerScope.of(context);
    final service = _resolveService(controller.data.services);
    if (service == null) return;

    setState(() => _isSubmitting = true);
    try {
      String? locationId = _address?.id;
      final typedAddress = _address?.lines ?? _addressController.text.trim();
      if (locationId == null && controller.repository.api.hasToken && typedAddress.isNotEmpty) {
        await controller.saveServiceLocation(
          label: 'Service Location',
          address: typedAddress,
        );
        final addresses = controller.data.addresses;
        if (addresses.isNotEmpty) locationId = addresses.first.id;
      }
      final booking = await controller.repository.confirmBooking(
        service: service,
        scheduledAt: _resolveDateTime(),
        address: typedAddress,
        customerName: controller.customer?.name ?? _nameController.text.trim(),
        contactNumber: _phoneController.text.trim(),
        notes: _notesController.text.trim(),
        serviceLocationId: locationId,
        products: _products
            .where((product) => _selectedProducts.containsKey(product.id))
            .map(
              (product) => ProductSelection(
                productId: product.id,
                quantity: _selectedProducts[product.id]!,
              ),
            )
            .toList(),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => BookingSuccessScreen(booking: booking),
        ),
      );
      await controller.reload();
    } on Object catch (error) {
      if (mounted) {
        final message = error is DataFailure
            ? error.message
            : 'Please try again.';
        setState(() => _error = 'Booking failed. $message');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = CustomerScope.of(context).data;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Service'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _isSubmitting ? null : _back,
          tooltip: 'Back',
        ),
      ),
      body: Column(
        children: [
          BookingStepper(currentStep: _currentStep, steps: _steps),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              14,
              AppTheme.gutter,
              0,
            ),
            child: BookingStepLabels(currentStep: _currentStep, steps: _steps),
          ),
          const Divider(height: 24),
          Expanded(child: _stepBody(context, data)),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        label: _currentStep == _steps.length - 1
            ? 'Confirm Booking'
            : 'Continue',
        isLoading: _isSubmitting,
        error: _error,
        enabled: _canContinue,
        onPressed: _next,
      ),
    );
  }

  Widget _stepBody(BuildContext context, AppData data) {
    if (data.isLoadingData && data.services.isEmpty) {
      return const SkeletonList(itemCount: 4, itemHeight: 72);
    }
    final service = _resolveService(data.services);
    return switch (_currentStep) {
      0 => _ServiceStep(
        services: data.services,
        selectedId: _serviceId,
        onSelect: (id) => setState(() {
          _serviceId = id;
          _error = '';
        }),
      ),
      1 => _DetailsStep(
        addresses: data.addresses,
        selectedAddress: _address,
        notesController: _notesController,
        nameController: _nameController,
        phoneController: _phoneController,
        emailController: _emailController,
        addressController: _addressController,
        paymentMode: _paymentMode,
        onDetailsChanged: () => setState(() => _error = ''),
        onAddressSelected: (address) => setState(() {
          _address = address;
          _error = '';
        }),
        onAddressTyped: (value) => setState(() => _address = null),
        onPaymentChanged: (mode) => setState(() => _paymentMode = mode),
        guestMode: _guestMode,
      ),
      2 => _ProductsStep(
        products: _products,
        quantities: _selectedProducts,
        isLoading: _isLoadingProducts,
        error: _productsError,
        hasCompany: CustomerScope.of(context).customer?.companySlug
                ?.trim()
                .isNotEmpty ==
            true,
        onRetry: () => _loadProducts(retry: true),
        onQuantityChanged: _changeProductQuantity,
      ),
      _ => _ConfirmStep(
        service: service,
        address: _address?.lines ?? _addressController.text.trim(),
        notes: _notesController.text.trim(),
        paymentMode: _paymentMode,
        guestMode: _guestMode,
        products: _products
            .where((product) => _selectedProducts.containsKey(product.id))
            .map(
              (product) => (
                product: product,
                quantity: _selectedProducts[product.id]!,
              ),
            )
            .toList(),
      ),
    };
  }
}

/// Step 3 — browse optional products and select quantities.
class _ProductsStep extends StatelessWidget {
  const _ProductsStep({
    required this.products,
    required this.quantities,
    required this.isLoading,
    required this.error,
    required this.hasCompany,
    required this.onRetry,
    required this.onQuantityChanged,
  });

  final List<Product> products;
  final Map<String, int> quantities;
  final bool isLoading;
  final String? error;
  final bool hasCompany;
  final VoidCallback onRetry;
  final void Function(Product product, int change) onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    if (!hasCompany) {
      return const EmptyState(
        icon: Icons.storefront_outlined,
        title: 'Products unavailable',
        message:
            'Sign in with a customer profile linked to a company to browse products. Products are optional.',
      );
    }
    if (isLoading) {
      return const SkeletonList(itemCount: 3, itemHeight: 140);
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 36),
              const SizedBox(height: 10),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (products.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No products available',
        message: 'There are no active products in this company catalogue.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        4,
        AppTheme.gutter,
        24,
      ),
      itemCount: products.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            'Add optional products to your booking. You can continue without selecting any.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        final product = products[index - 1];
        final quantity = quantities[product.id] ?? 0;
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.photos.isNotEmpty) ...[
                SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: product.photos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, photoIndex) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        product.photos[photoIndex],
                        width: 160,
                        height: 128,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 160,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (product.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            product.description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          Formatters.rupees(product.price),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (quantity == 0)
                    OutlinedButton(
                      onPressed: () => onQuantityChanged(product, 1),
                      child: const Text('Add'),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => onQuantityChanged(product, -1),
                          tooltip: 'Remove one ${product.name}',
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$quantity'),
                        IconButton(
                          onPressed: () => onQuantityChanged(product, 1),
                          tooltip: 'Add one ${product.name}',
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Step 1 — choose the service to book.
class _ServiceStep extends StatelessWidget {
  const _ServiceStep({
    required this.services,
    required this.selectedId,
    required this.onSelect,
  });

  final List<WaterService> services;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const EmptyState(
        icon: Icons.water_drop_outlined,
        title: 'No services available',
        message: 'We could not load services right now.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        4,
        AppTheme.gutter,
        24,
      ),
      itemCount: services.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final service = services[index];
        return ServiceTile(
          title: service.name,
          subtitle: '${service.durationLabel} • ${service.priceLabel}',
          icon: service.icon,
          selected: service.id == selectedId,
          trailing: service.id == selectedId
              ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
              : null,
          onTap: () => onSelect(service.id),
        );
      },
    );
  }
}

/// Step 2 — pick a day and a technician time slot.
class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.addresses,
    required this.selectedAddress,
    required this.notesController,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.addressController,
    required this.paymentMode,
    required this.onDetailsChanged,
    required this.onAddressSelected,
    required this.onAddressTyped,
    required this.onPaymentChanged,
    required this.guestMode,
  });

  static const List<String> paymentModes = <String>[
    'Pay after service',
    'UPI / Card now',
  ];

  final bool guestMode;

  final List<ServiceAddress> addresses;
  final ServiceAddress? selectedAddress;
  final TextEditingController notesController;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController addressController;
  final String paymentMode;
  final VoidCallback onDetailsChanged;
  final ValueChanged<ServiceAddress> onAddressSelected;
  final ValueChanged<String> onAddressTyped;
  final ValueChanged<String> onPaymentChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        4,
        AppTheme.gutter,
        24,
      ),
      children: [
        Text('Visit address, notes and payment preference', style: textTheme.titleMedium),
        const SizedBox(height: 10),
        TextField(
          controller: nameController,
          onChanged: (_) => onDetailsChanged(),
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Full Name *'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: phoneController,
          onChanged: (_) => onDetailsChanged(),
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Mobile Number *'),
        ),
        const SizedBox(height: 10),
        TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address (optional)')),
        const SizedBox(height: 20),
        Text('Saved addresses', style: textTheme.titleMedium),
        const SizedBox(height: 10),
        if (addresses.isEmpty)
          const InfoNote(
            icon: Icons.home_outlined,
            message: 'No saved addresses yet — add one below.',
          )
        else
          ...addresses.map(
            (address) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AddressTile(
                address: address,
                selected: address.id == selectedAddress?.id,
                onTap: () => onAddressSelected(address),
              ),
            ),
          ),
        const SizedBox(height: 14),
        Text('Or enter a new address', style: textTheme.titleMedium),
        const SizedBox(height: 10),
        TextField(
          controller: addressController,
          onChanged: onAddressTyped,
          minLines: 2,
          maxLines: 3,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Flat, street, landmark, city',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 20),
        Text('Payment preference', style: textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: paymentModes
              .map(
                (mode) => ChoicePill(
                  label: mode,
                  icon: mode.startsWith('Pay after')
                      ? Icons.payments_outlined
                      : Icons.credit_card_rounded,
                  selected: mode == paymentMode,
                  onTap: () => onPaymentChanged(mode),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        Text('Notes for the technician', style: textTheme.titleMedium),
        const SizedBox(height: 10),
        TextField(
          controller: notesController,
          minLines: 2,
          maxLines: 4,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Optional — e.g. gate code, brand of purifier',
          ),
        ),
      ],
    );
  }
}

/// Step 4 — review everything before confirming.
class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.service,
    required this.address,
    required this.notes,
    required this.paymentMode,
    required this.products,
    this.guestMode = false,
  });

  final WaterService? service;
  final String address;
  final String notes;
  final String paymentMode;
  final bool guestMode;
  final List<({Product product, int quantity})> products;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final resolved = service;
    if (resolved == null) {
      return const EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Missing details',
        message: 'Go back and complete the previous steps.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        4,
        AppTheme.gutter,
        24,
      ),
      children: [
        if (guestMode) ...[
          AppCard(
            color: AppColors.mintSoft,
            borderColor: AppColors.mint,
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guest booking',
                        style: textTheme.titleSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You do not need an account to book. Your name and phone are used only to confirm your visit.',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(icon: resolved.icon, size: 48, iconSize: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(resolved.name, style: textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          '${resolved.durationLabel} • ${resolved.priceLabel}',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: address.isEmpty ? '—' : address,
              ),
              DetailRow(
                icon: Icons.payments_outlined,
                label: 'Payment preference',
                value: paymentMode,
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text('Selected products', style: textTheme.titleSmall),
              const SizedBox(height: 6),
              if (products.isEmpty)
                Text(
                  'No products selected',
                  style: textTheme.bodySmall,
                )
              else
                ...products.map(
                  (selection) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${selection.product.name} × ${selection.quantity}',
                          ),
                        ),
                        Text(
                          Formatters.rupees(
                            selection.product.price * selection.quantity,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Estimated total',
                      style: textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    Formatters.rupees(
                      resolved.price +
                          products.fold<int>(
                            0,
                            (total, selection) =>
                                total +
                                selection.product.price * selection.quantity,
                          ),
                    ),
                    style: textTheme.titleSmall,
                  ),
                ],
              ),
              if (notes.isNotEmpty)
                DetailRow(
                  icon: Icons.sticky_note_2_outlined,
                  label: 'Notes',
                  value: notes,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          color: AppColors.mintSoft,
          borderColor: AppColors.mint,
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Free cancellation up to 2 hours before the slot.',
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sticky continue / confirm bar with inline validation messaging.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.label,
    required this.isLoading,
    required this.error,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final String error;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        10,
        AppTheme.gutter,
        12,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        error,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            FilledButton(
              onPressed: isLoading || !enabled ? null : onPressed,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
