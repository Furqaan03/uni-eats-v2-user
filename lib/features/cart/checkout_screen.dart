import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/uni_toast.dart';
import '../../models/order_model.dart';
import '../../services/mock_data_service.dart';
import '../../utils/currency_formatter.dart';
import '../orders/providers/orders_provider.dart';
import '../wallet/providers/wallet_provider.dart';
import 'providers/cart_provider.dart';

// TODO: All payment processing must move to a server-side Cloud Function
// before production to prevent tampering with amounts and secrets.

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  DeliveryType _deliveryType = DeliveryType.delivery;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final cart = ref.watch(cartProvider);
    final subtotal = ref.watch(cartTotalProvider);
    final deliveryFee = _deliveryType == DeliveryType.delivery ? 2.50 : 0.0;
    final total = subtotal + deliveryFee;
    final balance = ref.watch(walletBalanceProvider);
    final canPay = balance >= total;

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
                  subtitle: 'Student driver will deliver to you',
                  icon: Icons.delivery_dining,
                  fee: 2.50,
                  isSelected: _deliveryType == DeliveryType.delivery,
                  onTap: () => setState(() => _deliveryType = DeliveryType.delivery),
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
                Container(
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
                        child: Text(
                          'Noqoody',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!canPay)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Insufficient wallet balance. Please top up.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.danger,
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
                _SummaryRow(label: 'Subtotal', value: subtotal),
                _SummaryRow(label: 'Delivery Fee', value: deliveryFee),
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
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canPay ? () => _placeOrder(context, total) : null,
                  child: Text(
                    canPay
                        ? 'Pay ${CurrencyFormatter.format(total)}'
                        : 'Insufficient Balance',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _placeOrder(BuildContext context, double total) {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final orderId = const Uuid().v4().substring(0, 8).toUpperCase();
    final restaurantId = cart.first.item.restaurantId;
    final restaurant = MockDataService.restaurants.firstWhere(
      (r) => r.id == restaurantId,
    );

    final order = OrderModel(
      id: orderId,
      userId: MockDataService.currentUser.id,
      restaurantId: restaurantId,
      restaurantName: restaurant.name,
      items: List.from(cart),
      subtotal: total - (_deliveryType == DeliveryType.delivery ? 2.50 : 0.0),
      deliveryFee: _deliveryType == DeliveryType.delivery ? 2.50 : 0.0,
      total: total,
      status: OrderStatus.placed,
      deliveryType: _deliveryType,
      createdAt: DateTime.now(),
      estimatedDelivery: DateTime.now().add(
        Duration(minutes: restaurant.deliveryTimeMin + 5),
      ),
      timeline: [
        OrderTimelineStep(
          label: 'Order Placed',
          timestamp: DateTime.now(),
          isComplete: true,
        ),
        const OrderTimelineStep(label: 'Preparing', isComplete: false),
        const OrderTimelineStep(label: 'On the Way', isComplete: false),
        const OrderTimelineStep(label: 'Delivered', isComplete: false),
      ],
    );

    final paid = ref.read(walletBalanceProvider.notifier).pay(
          total,
          orderId: orderId,
          description: '${restaurant.name} — ${_deliveryType.name}',
        );

    if (!paid) {
      UniToast.show(context, 'Payment failed');
      return;
    }

    ref.read(ordersProvider.notifier).addOrder(order);
    ref.read(cartProvider.notifier).clear();

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
  final VoidCallback onTap;

  const _DeliveryOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.fee,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
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
                    style: AppTypography.caption.copyWith(color: textSecondary),
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
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? AppTypography.subheading.copyWith(color: textPrimary)
                : AppTypography.body.copyWith(color: AppColors.lightTextSecondary),
          ),
          Text(
            CurrencyFormatter.format(value),
            style: isTotal
                ? AppTypography.subheading.copyWith(color: AppColors.primary)
                : AppTypography.body.copyWith(color: textPrimary),
          ),
        ],
      ),
    );
  }
}
