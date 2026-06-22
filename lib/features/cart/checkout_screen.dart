import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../restaurant/providers/restaurant_status_provider.dart';
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

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  DeliveryType _deliveryType = DeliveryType.delivery;
  final _voucherCtrl = TextEditingController();
  String? _appliedVoucher;
  double _voucherDiscount = 0;
  String? _voucherError;
  bool _isPlacingOrder = false;

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

  @override
  void dispose() {
    _voucherCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final cart = ref.watch(cartProvider);
    final subtotal = ref.watch(cartTotalProvider);
    final deliveryFee = _deliveryType == DeliveryType.delivery ? 2.50 : 0.0;
    final total = (subtotal + deliveryFee - _voucherDiscount).clamp(0.0, double.infinity);
    final balance = ref.watch(availableBalanceProvider);
    final restaurantStatus = cart.isEmpty
        ? const RestaurantStatus()
        : ref.watch(restaurantStatusProvider(cart.first.item.restaurantId)).valueOrNull ??
            const RestaurantStatus();
    final canPay = balance >= total && restaurantStatus.isOrderable;

    final capacity = ref.watch(deliveryCapacityProvider).valueOrNull;
    // Hard block only when literally nobody is online — soft-warn instead of
    // blocking when drivers are online but stretched thin, so a borderline
    // case doesn't lose the order outright.
    final deliveryBlocked = capacity != null && !capacity.hasAnyDriver;
    final deliveryTight = capacity != null && capacity.hasAnyDriver && !capacity.hasCapacity;
    if (deliveryBlocked && _deliveryType == DeliveryType.delivery) {
      // Auto-switch to Pickup rather than leaving an unselectable option
      // selected — runs post-frame since this is read during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _deliveryType == DeliveryType.delivery) {
          setState(() => _deliveryType = DeliveryType.pickup);
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
                  subtitle: deliveryBlocked
                      ? 'No drivers available right now'
                      : deliveryTight
                          ? 'Drivers are busy — delivery may be delayed'
                          : 'Student driver will deliver to you',
                  icon: Icons.delivery_dining,
                  fee: 2.50,
                  isSelected: _deliveryType == DeliveryType.delivery,
                  disabled: deliveryBlocked,
                  warning: deliveryTight,
                  onTap: deliveryBlocked
                      ? null
                      : () => setState(() => _deliveryType = DeliveryType.delivery),
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
    final _rawNum = (1000 + orderId.hashCode.abs() % 9000).toString();
    final orderNumber = '#${_deliveryType == DeliveryType.pickup ? 'P' : 'D'}$_rawNum';
    final restaurantId = cart.first.item.restaurantId;
    final restaurant = MockDataService.restaurants
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
    final cartSubtotal = ref.read(cartTotalProvider);
    final deliveryFee = _deliveryType == DeliveryType.delivery ? 2.50 : 0.0;
    final subtotal = cartSubtotal;
    final estimatedDelivery = DateTime.now().add(
      Duration(minutes: restaurant.deliveryTimeMin + 5),
    );

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
          estimatedDelivery: estimatedDelivery,
          discount: _voucherDiscount,
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
