import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/uni_toast.dart';
import '../../models/order_model.dart';
import '../../models/restaurant_model.dart';
import '../../services/firestore_order_service.dart';
import '../../services/mock_data_service.dart';
import '../../utils/currency_formatter.dart';
import '../home/providers/notifications_provider.dart';
import '../orders/providers/orders_provider.dart';
import '../profile/providers/preferences_provider.dart';
import '../profile/widgets/location_pin_picker.dart';
import '../restaurant/providers/restaurant_status_provider.dart';
import '../restaurant/providers/restaurants_provider.dart';
import '../wallet/providers/wallet_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/delivery_capacity_provider.dart';

// TODO: All payment processing must move to a server-side Cloud Function
// before production to prevent tampering with amounts and secrets.

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

/// Flat delivery fee — confirmed fixed business rule, equal to the driver's
/// flat payout (kDriverPayoutPerDelivery in the driver app's
/// firestore_order_service.dart). The platform takes no margin on delivery.
/// Previously hardcoded to 2.50, which didn't match the actual agreed rate.
const kDeliveryFee = 5.0;

/// Minimum lead time for a scheduled order — the kitchen needs at least this
/// long between placing the order and the requested pickup/delivery time.
const kScheduleLeadTime = Duration(minutes: 25);

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  DeliveryType _deliveryType = DeliveryType.delivery;
  DateTime? _scheduledFor;
  final _voucherCtrl = TextEditingController();
  String? _appliedVoucher;
  double _voucherDiscount = 0;
  String? _voucherError;
  bool _isPlacingOrder = false;
  SavedLocation? _selectedLocation;
  bool _locationInitialized = false;
  // Only nag once per visit to this screen — re-tapping Delivery after
  // already confirming (or after bouncing to Pickup and back) shouldn't
  // show the same "drivers are busy" prompt again.
  bool _tightWarningAcknowledged = false;

  // Mock vouchers — in production these would come from Firestore per restaurant
  static const _mockVouchers = <String, (String type, double value, double min)>{
    'WELCOME10': ('percent', 10, 0),
    'SAVE5':     ('flat',    5,  20),
    'UDST15':    ('percent', 15, 30),
  };

  void _applyVoucher(double subtotal) {
    final code = _voucherCtrl.text.trim().toUpperCase();
    final entry = _mockVouchers[code];
    if (entry == null) {
      setState(() { _voucherError = 'Invalid voucher code.'; _voucherDiscount = 0; _appliedVoucher = null; });
      return;
    }
    final (type, value, min) = entry;
    if (subtotal < min) {
      setState(() { _voucherError = 'Min order QAR ${min.toStringAsFixed(0)} required.'; _voucherDiscount = 0; _appliedVoucher = null; });
      return;
    }
    final discount = type == 'percent'
        ? (subtotal * value / 100).clamp(0.0, subtotal)
        : value.clamp(0.0, subtotal);
    setState(() { _appliedVoucher = code; _voucherDiscount = discount; _voucherError = null; });
  }

  void _removeVoucher() {
    setState(() { _appliedVoucher = null; _voucherDiscount = 0; _voucherError = null; _voucherCtrl.clear(); });
  }

  /// Lets the customer schedule this order for a future pickup/delivery
  /// time instead of ASAP — must be at least [kScheduleLeadTime] from now,
  /// matching `#SP`/`#SD` order numbers' meaning at place-order time.
  Future<void> _pickScheduleTime(BuildContext context) async {
    final now = DateTime.now();
    final earliest = now.add(kScheduleLeadTime);

    final date = await showDatePicker(
      context: context,
      initialDate: earliest,
      firstDate: earliest,
      lastDate: now.add(const Duration(days: 7)),
    );
    if (date == null) return;
    if (!context.mounted) return;

    final initialTime = TimeOfDay.fromDateTime(
      // If they picked today, default the time picker to the earliest
      // allowed slot rather than the current clock time (which would be
      // too soon and get rejected below anyway).
      date.year == earliest.year && date.month == earliest.month && date.day == earliest.day
          ? earliest
          : DateTime(date.year, date.month, date.day, 12),
    );
    final time = await showTimePicker(context: context, initialTime: initialTime);
    if (time == null) return;

    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (picked.isBefore(earliest)) {
      if (context.mounted) {
        UniToast.show(
          context,
          'Please pick a time at least ${kScheduleLeadTime.inMinutes} minutes from now.',
        );
      }
      return;
    }
    setState(() => _scheduledFor = picked);
  }

  /// Drivers are online but every one of them is already at capacity —
  /// real capacity, just stretched thin, not the zero-drivers case (that's
  /// `deliveryBlocked`, a hard stop). Ask once whether to wait it out or
  /// switch to pickup instead, rather than silently letting the order
  /// place into a queue that may take a while to clear.
  Future<void> _confirmTightDelivery(BuildContext context) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Drivers Are Busy'),
        content: const Text(
          'All online drivers are currently at capacity. Your order may sit '
          'longer than usual before one becomes free. Continue with delivery '
          'anyway, or switch to pickup instead?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'pickup'),
            child: const Text('Switch to Pickup'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'continue'),
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );

    if (choice == 'pickup') {
      setState(() => _deliveryType = DeliveryType.pickup);
    } else if (choice == 'continue') {
      setState(() {
        _deliveryType = DeliveryType.delivery;
        _tightWarningAcknowledged = true;
      });
    }
    // Dismissed without a choice (back button/tap outside) — leave selection
    // untouched rather than assuming either answer.
  }

  @override
  void dispose() {
    _voucherCtrl.dispose();
    super.dispose();
  }

  void _showLocationPicker(BuildContext context, List<SavedLocation> savedLocations) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _LocationPickerSheet(
        savedLocations: savedLocations,
        selected: _selectedLocation,
        onSelect: (loc) {
          setState(() => _selectedLocation = loc);
          Navigator.of(sheetCtx, rootNavigator: true).pop();
        },
        onAddNew: () {
          Navigator.of(sheetCtx, rootNavigator: true).pop();
          _showAddLocation(context);
        },
        mutedColor: textMuted,
      ),
    );
  }

  void _showAddLocation(BuildContext context) {
    final labelCtr = TextEditingController();
    final addressCtr = TextEditingController();
    var emoji = '📍';
    double? pinX;
    double? pinY;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setS) {
          return Container(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, 20 + MediaQuery.of(sheetCtx).viewInsets.bottom),
            decoration: BoxDecoration(
              color: Theme.of(sheetCtx).cardTheme.color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add New Location',
                      style: AppTypography.heading
                          .copyWith(color: Theme.of(sheetCtx).colorScheme.onSurface)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: kLocationEmojiOptions.map((e) {
                      final active = e == emoji;
                      return GestureDetector(
                        onTap: () => setS(() => emoji = e),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: active ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: active ? AppColors.primary : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 16)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: labelCtr,
                    decoration: InputDecoration(
                      labelText: 'Label (e.g. Home, Office)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressCtr,
                    decoration: InputDecoration(
                      labelText: 'Address / Building',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  LocationPinPicker(
                    onPinSet: (offset) => setS(() {
                      pinX = offset.dx;
                      pinY = offset.dy;
                    }),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final label = labelCtr.text.trim();
                        final address = addressCtr.text.trim();
                        if (label.isEmpty || address.isEmpty) return;
                        final entry = SavedLocation(
                            emoji: emoji, label: label, address: address, mapX: pinX, mapY: pinY);
                        await ref.read(savedLocationsProvider.notifier).add(entry);
                        setState(() => _selectedLocation = entry);
                        if (sheetCtx.mounted) Navigator.of(sheetCtx, rootNavigator: true).pop();
                        if (context.mounted) UniToast.show(context, 'Location added and selected');
                      },
                      child: const Text('Save & Select'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final savedLocations = ref.watch(savedLocationsProvider);
    if (!_locationInitialized && savedLocations.isNotEmpty) {
      _locationInitialized = true;
      final defaultDropoff = ref.read(defaultDropoffProvider);
      _selectedLocation = savedLocations.firstWhere(
        (l) => l.label == defaultDropoff.name || l.address.contains(defaultDropoff.code),
        orElse: () => savedLocations.first,
      );
    }

    final cart = ref.watch(cartProvider);
    final subtotal = ref.watch(cartTotalProvider);
    final deliveryFee = _deliveryType == DeliveryType.delivery ? kDeliveryFee : 0.0;
    final total = (subtotal + deliveryFee - _voucherDiscount).clamp(0.0, double.infinity);
    final balance = ref.watch(availableBalanceProvider);
    final restaurantStatus = cart.isEmpty
        ? const RestaurantStatus()
        : ref.watch(restaurantStatusProvider(cart.first.item.restaurantId)).valueOrNull ??
            const RestaurantStatus();
    final needsLocation = _deliveryType == DeliveryType.delivery && _selectedLocation == null;
    final canPay = balance >= total && restaurantStatus.isOrderable && !needsLocation;

    final allRestaurants = ref.watch(restaurantsProvider).valueOrNull ?? MockDataService.restaurants;
    final restaurantOffersDelivery = cart.isEmpty ||
        (allRestaurants.cast<RestaurantModel?>().firstWhere(
              (r) => r!.id == cart.first.item.restaurantId,
              orElse: () => null,
            )?.offersDelivery ??
            true);

    final capacity = ref.watch(deliveryCapacityProvider).valueOrNull;
    // Hard block only when literally nobody is online — soft-warn instead of
    // blocking when drivers are online but stretched thin, so a borderline
    // case doesn't lose the order outright.
    final deliveryBlocked =
        !restaurantOffersDelivery || (capacity != null && !capacity.hasAnyDriver);
    final deliveryTight = capacity != null && capacity.hasAnyDriver && !capacity.hasCapacity;
    if (deliveryBlocked && _deliveryType == DeliveryType.delivery) {
      // Auto-switch to Pickup rather than leaving an unselectable option
      // selected — runs post-frame since this is read during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _deliveryType == DeliveryType.delivery) {
          setState(() => _deliveryType = DeliveryType.pickup);
        }
      });
    } else if (deliveryTight && !_tightWarningAcknowledged && _deliveryType == DeliveryType.delivery) {
      // Delivery defaults to selected on first load — if capacity is
      // already tight the moment this screen opens, the tap handler below
      // never fires to surface the warning, so check once here too.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && deliveryTight && !_tightWarningAcknowledged && _deliveryType == DeliveryType.delivery) {
          _confirmTightDelivery(context);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Checkout',
          style: AppTypography.heading.copyWith(color: textPrimary),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Delivery Options',
                  style: AppTypography.subheading.copyWith(color: textPrimary),
                ),
                const SizedBox(height: 12),
                _DeliveryOptionCard(
                  title: 'Delivery',
                  subtitle: !restaurantOffersDelivery
                      ? 'This restaurant doesn\'t offer delivery'
                      : deliveryBlocked
                          ? 'No drivers available right now'
                          : deliveryTight
                              ? 'Drivers are busy — delivery may be delayed'
                              : 'Student driver will deliver to you',
                  icon: Icons.delivery_dining,
                  fee: kDeliveryFee,
                  isSelected: _deliveryType == DeliveryType.delivery,
                  disabled: deliveryBlocked,
                  warning: deliveryTight,
                  onTap: deliveryBlocked
                      ? null
                      : () {
                          if (deliveryTight &&
                              !_tightWarningAcknowledged &&
                              _deliveryType != DeliveryType.delivery) {
                            _confirmTightDelivery(context); // ignore: discarded_futures
                          } else {
                            setState(() => _deliveryType = DeliveryType.delivery);
                          }
                        },
                ),
                const SizedBox(height: 10),
                _DeliveryOptionCard(
                  title: 'Pickup',
                  subtitle: 'Pick up your order yourself',
                  icon: Icons.storefront,
                  fee: 0.0,
                  isSelected: _deliveryType == DeliveryType.pickup,
                  onTap: () => setState(() => _deliveryType = DeliveryType.pickup),
                ),
                if (_deliveryType == DeliveryType.delivery) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Deliver To',
                    style: AppTypography.subheading.copyWith(color: textPrimary),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _showLocationPicker(context, savedLocations),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Text(_selectedLocation?.emoji ?? '📍', style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedLocation?.label ?? 'Select a drop-off location',
                                  style: AppTypography.subheading.copyWith(color: textPrimary, fontSize: 13),
                                ),
                                if (_selectedLocation != null)
                                  Text(
                                    _selectedLocation!.address,
                                    style: AppTypography.caption.copyWith(color: textSecondary),
                                  ),
                              ],
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down,
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'When?',
                  style: AppTypography.subheading.copyWith(color: textPrimary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _WhenChip(
                        icon: Icons.bolt,
                        label: 'ASAP',
                        isSelected: _scheduledFor == null,
                        onTap: () => setState(() => _scheduledFor = null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _WhenChip(
                        icon: Icons.schedule,
                        label: 'Schedule',
                        isSelected: _scheduledFor != null,
                        onTap: () => _pickScheduleTime(context),
                      ),
                    ),
                  ],
                ),
                if (_scheduledFor != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (_deliveryType == DeliveryType.pickup ? 'Ready for pickup at ' : 'Arriving around ') +
                                DateFormat('MMM d, h:mm a').format(_scheduledFor!),
                            style: AppTypography.body.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _scheduledFor = null),
                          child: Icon(Icons.close, size: 16, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Payment Method',
                  style: AppTypography.subheading.copyWith(color: textPrimary),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    await context.push('/wallet');
                    // Wallet screen was popped (e.g. after topping up) —
                    // ref.watch above already reflects the new balance.
                  },
                  child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.walletGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Uni Eats Wallet',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          Text(
                            CurrencyFormatter.compact(balance),
                            style: AppTypography.subheading.copyWith(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Noqoody',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
                if (!restaurantStatus.isOrderable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      restaurantStatus.isOpen
                          ? 'This restaurant is too busy to accept new orders right now.'
                          : 'This restaurant is closed right now.',
                      style: AppTypography.caption.copyWith(color: AppColors.danger),
                    ),
                  )
                else if (!canPay)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () => context.push('/wallet'),
                      child: Text(
                        'Insufficient wallet balance. Tap to top up.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.danger,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Order Summary',
                  style: AppTypography.subheading.copyWith(color: textPrimary),
                ),
                const SizedBox(height: 12),
                ...cart.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item.quantity}x ${item.item.name}',
                            style: AppTypography.body.copyWith(color: textSecondary),
                          ),
                          Text(
                            CurrencyFormatter.format(item.total),
                            style: AppTypography.body.copyWith(color: textPrimary),
                          ),
                        ],
                      ),
                    )),
                const Divider(height: 32),
                // ── Voucher input ──────────────────────────────────
                if (_appliedVoucher == null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _voucherCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'Voucher code',
                            hintStyle: AppTypography.caption
                                .copyWith(color: textSecondary),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _applyVoucher(subtotal),
                        style: OutlinedButton.styleFrom(
                          side:
                              const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Apply',
                            style: AppTypography.body.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  if (_voucherError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_voucherError!,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.danger)),
                    ),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Voucher $_appliedVoucher applied',
                            style: AppTypography.body.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        GestureDetector(
                          onTap: _removeVoucher,
                          child: const Icon(Icons.close,
                              size: 16, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // ── Price breakdown ────────────────────────────────
                _SummaryRow(label: 'Subtotal', value: subtotal),
                if (deliveryFee > 0)
                  _SummaryRow(label: 'Delivery Fee', value: deliveryFee),
                if (_voucherDiscount > 0)
                  _SummaryRow(
                    label: 'Voucher ($_appliedVoucher)',
                    value: -_voucherDiscount,
                    isDiscount: true,
                  ),
                _SummaryRow(
                  label: 'Total',
                  value: total,
                  isTotal: true,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (canPay && !_isPlacingOrder) ? () => _placeOrder(context, total) : null, // ignore: discarded_futures
                      child: _isPlacingOrder
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              !restaurantStatus.isOrderable
                                  ? (restaurantStatus.isOpen ? 'Restaurant Busy' : 'Restaurant Closed')
                                  : needsLocation
                                      ? 'Select a Drop-off Location'
                                      : (canPay
                                          ? 'Pay ${CurrencyFormatter.format(total)}'
                                          : 'Insufficient Balance'),
                            ),
                    ),
                  ),
                  if (canPay) ...[
                    const SizedBox(height: 6),
                    Text(
                      "You won't be charged until the restaurant accepts your order",
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder(BuildContext context, double total) async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty || _isPlacingOrder) return;
    setState(() => _isPlacingOrder = true);

    final orderId = const Uuid().v4().substring(0, 8).toUpperCase();
    final rawNum = (1000 + orderId.hashCode.abs() % 9000).toString();
    final prefix = _scheduledFor != null
        ? (_deliveryType == DeliveryType.pickup ? 'SP' : 'SD')
        : (_deliveryType == DeliveryType.pickup ? 'P' : 'D');
    final orderNumber = '#$prefix$rawNum';
    final restaurantId = cart.first.item.restaurantId;
    final allRestaurants = ref.read(restaurantsProvider).valueOrNull ?? MockDataService.restaurants;
    final restaurant = allRestaurants
        .cast<RestaurantModel?>()
        .firstWhere((r) => r!.id == restaurantId, orElse: () => null);
    if (restaurant == null) {
      UniToast.show(context, 'Something went wrong with your cart. Please try again.');
      setState(() => _isPlacingOrder = false);
      return;
    }

    // Re-check live status right before placing — it may have changed since
    // the screen first loaded (vendor went busy/closed mid-checkout).
    final liveStatus = kUseFirebase
        ? await FirestoreOrderService.instance.streamRestaurantStatus(restaurantId).first
        : null;
    final isOrderable = liveStatus == null ||
        ((liveStatus['isOpen'] as bool? ?? true) && !(liveStatus['isBusy'] as bool? ?? false));
    if (!isOrderable) {
      UniToast.show(context, '${restaurant.name} stopped accepting orders. Please try again later.');
      setState(() => _isPlacingOrder = false);
      return;
    }

    // Re-check delivery eligibility right before placing too — the UI auto-
    // switches Delivery to Pickup when drivers go offline, but that's a
    // post-frame effect racing against this button's tap. Without this
    // check, a delivery order could be placed for a pickup-only restaurant
    // or with zero drivers online, and sit unclaimed in 'awaitingDriver'
    // forever.
    if (_deliveryType == DeliveryType.delivery) {
      if (!restaurant.offersDelivery) {
        UniToast.show(context, '${restaurant.name} doesn\'t offer delivery — switched you to Pickup.');
        setState(() {
          _deliveryType = DeliveryType.pickup;
          _isPlacingOrder = false;
        });
        return;
      }
      if (kUseFirebase) {
        final liveCapacity = await FirestoreOrderService.instance.streamDeliveryCapacity().first;
        if (!liveCapacity.hasAnyDriver) {
          UniToast.show(context, 'No drivers are available right now — switched you to Pickup.');
          setState(() {
            _deliveryType = DeliveryType.pickup;
            _isPlacingOrder = false;
          });
          return;
        }
      }
    }
    final cartSubtotal = ref.read(cartTotalProvider);
    final deliveryFee = _deliveryType == DeliveryType.delivery ? kDeliveryFee : 0.0;
    final subtotal = cartSubtotal;
    final estimatedDelivery = _scheduledFor ??
        DateTime.now().add(Duration(minutes: restaurant.deliveryTimeMin + 5));

    final order = OrderModel(
      id: orderId,
      orderNumber: orderNumber,
      userId: MockDataService.currentUser.id,
      restaurantId: restaurantId,
      restaurantName: restaurant.name,
      items: List.from(cart),
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      total: total,
      status: OrderStatus.placed,
      deliveryType: _deliveryType,
      createdAt: DateTime.now(),
      estimatedDelivery: estimatedDelivery,
      scheduledFor: _scheduledFor,
      deliveryAddress: _deliveryType == DeliveryType.delivery && _selectedLocation != null
          ? '${_selectedLocation!.label} — ${_selectedLocation!.address}'
          : null,
      timeline: _deliveryType == DeliveryType.pickup
          ? [
              OrderTimelineStep(
                label: 'Order Placed',
                timestamp: DateTime.now(),
                isComplete: true,
                isCurrent: true,
              ),
              const OrderTimelineStep(label: 'Preparing'),
              const OrderTimelineStep(label: 'Ready for Pickup'),
              const OrderTimelineStep(label: 'Picked Up'),
            ]
          : [
              OrderTimelineStep(
                label: 'Order Placed',
                timestamp: DateTime.now(),
                isComplete: true,
                isCurrent: true,
              ),
              const OrderTimelineStep(label: 'Finding a Driver'),
              const OrderTimelineStep(label: 'Preparing'),
              const OrderTimelineStep(label: 'Driver Arrived'),
              const OrderTimelineStep(label: 'Out for Delivery'),
              const OrderTimelineStep(label: 'Driver Has Arrived'),
              const OrderTimelineStep(label: 'Delivered'),
            ],
    );

    // Hold the funds now, but don't deduct them — actual payment is captured
    // once the vendor accepts the order (see OrdersNotifier._resolveEscrow).
    final held = ref.read(walletBalanceProvider.notifier).hold(total, orderId: orderId);

    if (!held) {
      UniToast.show(context, 'Insufficient wallet balance');
      setState(() => _isPlacingOrder = false);
      return;
    }

    // Optimistic local update — Firestore sync happens in background
    ref.read(ordersProvider.notifier).addOrder(order);
    ref.read(cartProvider.notifier).clear();
    ref.read(notificationsProvider.notifier).scheduleOrderNotifications(restaurant.name);

    if (kUseFirebase) {
      try {
        await FirestoreOrderService.instance.placeOrder(
          orderId: orderId,
          orderNumber: orderNumber,
          userId: MockDataService.currentUser.id,
          vendorId: restaurantId,
          restaurantName: restaurant.name,
          items: cart,
          subtotal: subtotal,
          deliveryFee: deliveryFee,
          total: total,
          deliveryType: _deliveryType,
          customerName: MockDataService.currentUser.name,
          customerPhone: MockDataService.currentUser.phone,
          estimatedDelivery: estimatedDelivery,
          discount: _voucherDiscount,
          deliveryAddress: order.deliveryAddress,
          scheduledFor: _scheduledFor,
        );
      } catch (e) {
        // Order is still visible locally; Firestore write failed silently here.
        // In production this should queue a retry.
        debugPrint('[Firestore] placeOrder failed: $e');
      }
    }

    if (!context.mounted) return;
    UniToast.show(context, 'Order placed successfully');
    context.go('/orders');
  }
}

class _LocationPickerSheet extends StatelessWidget {
  final List<SavedLocation> savedLocations;
  final SavedLocation? selected;
  final ValueChanged<SavedLocation> onSelect;
  final VoidCallback onAddNew;
  final Color mutedColor;

  const _LocationPickerSheet({
    required this.savedLocations,
    required this.selected,
    required this.onSelect,
    required this.onAddNew,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Deliver To', style: AppTypography.heading.copyWith(color: textPrimary)),
          const SizedBox(height: 14),
          if (savedLocations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No saved locations yet — add one below',
                  style: AppTypography.caption.copyWith(color: mutedColor, fontSize: 11)),
            ),
          ...savedLocations.map((loc) {
            final active = loc.label == selected?.label && loc.address == selected?.address;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => onSelect(loc),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? AppColors.primary : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(loc.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.label,
                                style: AppTypography.subheading.copyWith(
                                    fontSize: 12,
                                    color: active ? AppColors.primary : textPrimary)),
                            Text(loc.address,
                                style: AppTypography.caption.copyWith(color: mutedColor, fontSize: 10)),
                          ],
                        ),
                      ),
                      if (active) const Icon(Icons.check_circle, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAddNew,
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Add New Location'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhenChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _WhenChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.12)
              : Theme.of(context).cardTheme.color,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.primary : textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.subheading.copyWith(
                color: isSelected ? AppColors.primary : textPrimary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final double fee;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool disabled;
  final bool warning;

  const _DeliveryOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.fee,
    required this.isSelected,
    required this.onTap,
    this.disabled = false,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final subtitleColor = disabled
        ? AppColors.danger
        : warning
            ? Colors.orange
            : textSecondary;

    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.12)
              : Theme.of(context).cardTheme.color,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : isDark
                        ? AppColors.darkSurface2
                        : AppColors.lightSurface2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.subheading.copyWith(
                      color: textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: subtitleColor,
                      fontWeight: (disabled || warning) ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              fee == 0 ? 'Free' : CurrencyFormatter.format(fee),
              style: AppTypography.subheading.copyWith(
                color: AppColors.primary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isTotal;
  final bool isDiscount;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;

    Color valueColor;
    if (isDiscount) {
      valueColor = AppColors.primary;
    } else if (isTotal) {
      valueColor = AppColors.primary;
    } else {
      valueColor = textPrimary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? AppTypography.subheading.copyWith(color: textPrimary)
                : AppTypography.body.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
          ),
          Text(
            isDiscount
                ? '- ${CurrencyFormatter.format(value.abs())}'
                : CurrencyFormatter.format(value),
            style: isTotal
                ? AppTypography.subheading.copyWith(color: valueColor)
                : AppTypography.body.copyWith(
                    color: valueColor,
                    fontWeight:
                        isDiscount ? FontWeight.w700 : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
