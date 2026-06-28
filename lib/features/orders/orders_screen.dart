import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/uni_toast.dart';
import '../../models/order_model.dart';
import '../../utils/currency_formatter.dart';
import '../cart/cart_restaurant_guard.dart';
import '../cart/providers/cart_provider.dart';
import 'providers/orders_provider.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _lastTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _lastTabIndex) {
        _lastTabIndex = _tabController.index;
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If home screen set a pending order to open, handle it after first frame.
    final pendingId = ref.read(pendingOrderDetailProvider);
    if (pendingId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingOrder(pendingId));
    }
  }

  void _openPendingOrder(String orderId) {
    if (!mounted) return;
    ref.read(pendingOrderDetailProvider.notifier).state = null;
    final activeOrders = ref.read(activeOrdersProvider);
    final order = activeOrders.cast<OrderModel?>().firstWhere(
          (o) => o?.id == orderId,
          orElse: () => null,
        );
    if (order == null) return;
    // Switch to Active tab.
    _tabController.animateTo(0);
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActiveDetailSheet(order: order),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = ref.watch(activeOrdersProvider);
    final pastOrders = ref.watch(pastOrdersProvider);
    final cancelledOrders = ref.watch(cancelledOrdersProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(activeCount: activeOrders.length),
            _PillTabBar(controller: _tabController),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ActiveTab(orders: activeOrders),
                  _PastTab(orders: pastOrders),
                  _CancelledTab(orders: cancelledOrders),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int activeCount;

  const _Header({required this.activeCount});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'My Orders',
            style: AppTypography.displayMedium.copyWith(
              color: textPrimary,
              fontSize: 20,
            ),
          ),
          if (activeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C3A1C)
                    : const Color(0xFFE8F5E8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$activeCount ACTIVE',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PillTabBar extends StatelessWidget {
  final TabController controller;

  const _PillTabBar({required this.controller});

  static const _labels = ['Active', 'Past', 'Cancelled'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface3 : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                  ),
                ],
        ),
        child: Row(
          children: List.generate(_labels.length, (index) {
            final isActive = controller.index == index;
            return Expanded(
              child: GestureDetector(
                onTap: () => controller.animateTo(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _labels[index],
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: isActive
                          ? Colors.white
                          : isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ───────────────────────── ACTIVE TAB ─────────────────────────

class _ActiveTab extends StatelessWidget {
  final List<OrderModel> orders;

  const _ActiveTab({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyState(
        icon: '🛵',
        title: 'No active orders',
        subtitle: 'Your current orders will show up here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(text: _sectionLabel(order)),
            _ActiveOrderCard(order: order),
          ],
        );
      },
    );
  }

  String _sectionLabel(OrderModel order) {
    return switch (order.status) {
      OrderStatus.awaitingDriver => '🔎 Finding a Driver',
      OrderStatus.preparing => '🍳 Preparing',
      OrderStatus.ready => order.deliveryType == DeliveryType.pickup
          ? '📦 Ready for Pickup'
          : '📦 Ready',
      OrderStatus.driverArrived => '🛵 Driver At Restaurant',
      OrderStatus.pickedUp => '📦 Picked Up by Driver',
      OrderStatus.delivering => '🛵 Out for Delivery',
      OrderStatus.arrived => '📍 Driver Has Arrived',
      OrderStatus.delivered => '✅ Delivered',
      _ => '🧾 Order Placed',
    };
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

const _kCancelReasons = [
  'Changed my mind',
  'Order is taking too long',
  'Ordered by mistake',
  'Found a better option',
  'Other',
];

/// Shows the cancellation reason picker, then cancels through
/// `OrdersNotifier.cancelOrder()` — the only path that both marks the order
/// locally-cancelled (so Firestore can't resurrect it) AND pushes the
/// cancellation to Firestore, which is what the vendor app actually reads.
/// A prior version of this flow called `updateOrder()` directly for one of
/// the two "Cancel" buttons, which only ever touched local state — the
/// vendor app never learned the order was cancelled and it stayed live in
/// their queue forever.
Future<void> _confirmAndCancelOrder(BuildContext context, WidgetRef ref, OrderModel order) async {
  String selectedReason = _kCancelReasons.first;
  final otherCtrl = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (_, setS) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This cannot be undone. Why are you cancelling?'),
              const SizedBox(height: 8),
              ..._kCancelReasons.map((reason) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(reason, style: const TextStyle(fontSize: 13)),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (v) => setS(() => selectedReason = v!),
                  )),
              if (selectedReason == 'Other')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextField(
                    controller: otherCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Tell us more (optional)',
                      isDense: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Order', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true) return;

  final reasonText = selectedReason == 'Other' && otherCtrl.text.trim().isNotEmpty
      ? otherCtrl.text.trim()
      : selectedReason;

  ref.read(ordersProvider.notifier).cancelOrder(order.id, reason: reasonText);
  if (context.mounted) UniToast.show(context, 'Order cancelled');
}

class _ActiveOrderCard extends ConsumerWidget {
  final OrderModel order;

  const _ActiveOrderCard({required this.order});

  void _showActiveDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActiveDetailSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final isDelivering = order.status == OrderStatus.delivering;
    final canCancel = order.status == OrderStatus.placed;

    return GestureDetector(
      onTap: () => _showActiveDetail(context, ref),
      child: Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface3 : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 12,
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDelivering
                    ? [AppColors.primary, AppColors.primaryDark]
                    : [AppColors.accent, AppColors.accentDark],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORDER ${order.orderNumber}',
                      style: AppTypography.label.copyWith(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 9,
                      ),
                    ),
                    Text(
                      order.restaurantName,
                      style: AppTypography.subheading.copyWith(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isDelivering ? 'Arriving in' : 'Est. ready',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 9,
                      ),
                    ),
                    Text(
                      order.estimatedDelivery != null
                          ? '${order.estimatedDelivery!.difference(DateTime.now()).inMinutes.clamp(0, 99)} min'
                          : '--',
                      style: AppTypography.displayMedium.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Steps row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: _StepsRow(steps: order.timeline),
          ),

          if (isDelivering) ...[
            _SepLine(isDark: isDark),
            // Driver row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryDark],
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('👨‍🎓', style: TextStyle(fontSize: 15)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.driverName ?? 'Driver',
                          style: AppTypography.subheading.copyWith(
                            color: textPrimary,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Student Delivery · ⭐ 4.9',
                          style: AppTypography.caption.copyWith(
                            color: textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CircleIconButton(
                    icon: Icons.call_outlined,
                    color: AppColors.primary,
                    onTap: () => UniToast.show(context, 'Calling ${order.driverName}…'),
                  ),
                  const SizedBox(width: 6),
                  _CircleIconButton(
                    icon: Icons.message_outlined,
                    color: AppColors.accent,
                    onTap: () => UniToast.show(context, 'Opening chat with ${order.driverName}…'),
                  ),
                ],
              ),
            ),
            _SepLine(isDark: isDark),
            // Items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  ...order.items.map(
                    (ci) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${ci.item.name} × ${ci.quantity}',
                            style: AppTypography.caption.copyWith(
                              color: textSecondary,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.compact(ci.total),
                            style: AppTypography.caption.copyWith(
                              color: textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: AppTypography.subheading.copyWith(
                          color: textPrimary,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.compact(order.total),
                        style: AppTypography.subheading.copyWith(
                          color: AppColors.primary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Track button — delivery orders only
            if (order.deliveryType == DeliveryType.delivery)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: GestureDetector(
                onTap: () => context.go('/tracking'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'Track on Map',
                        style: AppTypography.button.copyWith(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // Summary row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${_itemsSummary(order)} · ${CurrencyFormatter.compact(order.total)}',
                      style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 10),
                    ),
                  ),
                  _Tag(
                    label: order.deliveryType == DeliveryType.pickup ? 'Pickup' : 'Delivery',
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'View Details',
                      icon: Icons.info_outline_rounded,
                      primary: false,
                      onTap: () => _showActiveDetail(context, ref),
                    ),
                  ),
                  if (canCancel) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        label: 'Cancel',
                        icon: Icons.close_rounded,
                        primary: false,
                        onTap: () => _confirmAndCancelOrder(context, ref, order),
                        danger: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

// ───────────────────────── ACTIVE ORDER DETAIL SHEET ─────────────────────────

class _ActiveDetailSheet extends ConsumerWidget {
  final OrderModel order;

  const _ActiveDetailSheet({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface3 : AppColors.lightSurface;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final canCancel = order.status == OrderStatus.placed;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order Details',
                          style: AppTypography.heading.copyWith(
                              color: textPrimary, fontSize: 18)),
                      Text('${order.orderNumber} · ${order.restaurantName}',
                          style: AppTypography.caption.copyWith(
                              color: textMuted, fontSize: 10)),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: textMuted, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  // Status banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: order.status == OrderStatus.delivering
                            ? [AppColors.primary, AppColors.primaryDark]
                            : [AppColors.accent, AppColors.accentDark],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _statusTitle(order.status),
                                style: AppTypography.subheading.copyWith(
                                    color: Colors.white, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _statusSubtitle(order),
                                style: AppTypography.caption.copyWith(
                                    color: Colors.white70, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        if (order.estimatedDelivery != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('ETA',
                                  style: AppTypography.caption.copyWith(
                                      color: Colors.white60, fontSize: 9)),
                              Text(
                                '${order.estimatedDelivery!.difference(DateTime.now()).inMinutes.clamp(0, 99)} min',
                                style: AppTypography.displayMedium.copyWith(
                                    color: Colors.white, fontSize: 20),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Full timeline
                  _ReceiptSection(
                    title: 'Timeline',
                    isDark: isDark,
                    child: Column(
                      children: order.timeline.map((step) {
                        final isActive = step.isCurrent;
                        final isDone = step.isComplete && !step.isCurrent;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isDone || isActive
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: isDone || isActive
                                      ? null
                                      : Border.all(
                                          color: isDark
                                              ? AppColors.darkBorder
                                              : const Color(0xFFC8D8C8),
                                          width: 2),
                                ),
                                alignment: Alignment.center,
                                child: isDone
                                    ? const Icon(Icons.check,
                                        size: 11, color: Colors.white)
                                    : isActive
                                        ? Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                          )
                                        : null,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                step.label,
                                style: AppTypography.body.copyWith(
                                  fontSize: 12,
                                  color: isActive
                                      ? AppColors.primary
                                      : isDone
                                          ? textPrimary
                                          : textMuted,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Items
                  _ReceiptSection(
                    title: 'Your Order',
                    isDark: isDark,
                    child: Column(
                      children: [
                        ...order.items.map((ci) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(ci.item.name,
                                        style: AppTypography.body.copyWith(
                                            color: textPrimary, fontSize: 12)),
                                  ),
                                  Text('× ${ci.quantity}',
                                      style: AppTypography.caption.copyWith(
                                          color: textMuted, fontSize: 11)),
                                  const SizedBox(width: 12),
                                  Text(
                                      CurrencyFormatter.format(ci.total),
                                      style: AppTypography.subheading.copyWith(
                                          color: textPrimary, fontSize: 12)),
                                ],
                              ),
                            )),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Divider(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.black12,
                              height: 1),
                        ),
                        const SizedBox(height: 8),
                        // Subtotal
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtotal',
                                style: AppTypography.caption.copyWith(
                                    color: textMuted, fontSize: 11)),
                            Text(CurrencyFormatter.format(order.subtotal),
                                style: AppTypography.caption.copyWith(
                                    color: textMuted, fontSize: 11)),
                          ],
                        ),
                        if (order.deliveryFee > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Delivery fee',
                                  style: AppTypography.caption.copyWith(
                                      color: textMuted, fontSize: 11)),
                              Text(CurrencyFormatter.format(order.deliveryFee),
                                  style: AppTypography.caption.copyWith(
                                      color: textMuted, fontSize: 11)),
                            ],
                          ),
                        ],
                        Builder(builder: (_) {
                          final discount = order.subtotal + order.deliveryFee - order.total;
                          if (discount <= 0.001) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Discount',
                                    style: AppTypography.caption.copyWith(
                                        color: AppColors.primary, fontSize: 11)),
                                Text('- ${CurrencyFormatter.format(discount)}',
                                    style: AppTypography.caption.copyWith(
                                        color: AppColors.primary, fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                        Divider(
                            color: isDark ? Colors.white12 : Colors.black12,
                            height: 1),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total',
                                style: AppTypography.subheading.copyWith(
                                    color: textPrimary, fontSize: 13)),
                            Text(
                                CurrencyFormatter.format(order.total),
                                style: AppTypography.subheading.copyWith(
                                    color: AppColors.primary, fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'Help & Support',
                          icon: Icons.headset_mic_outlined,
                          primary: false,
                          onTap: () {
                            Navigator.pop(context);
                            UniToast.show(context, 'Opening support…');
                          },
                        ),
                      ),
                      if (canCancel) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            label: 'Cancel Order',
                            icon: Icons.close_rounded,
                            primary: false,
                            danger: true,
                            onTap: () {
                              Navigator.pop(context);
                              _confirmAndCancelOrder(context, ref, order); // ignore: discarded_futures
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusTitle(OrderStatus status) => switch (status) {
        OrderStatus.placed => 'Order Received',
        OrderStatus.awaitingDriver => 'Finding a Driver',
        OrderStatus.preparing => 'Being Prepared',
        OrderStatus.ready => order.deliveryType == DeliveryType.pickup
            ? 'Ready for Pickup'
            : 'Ready — Driver Coming',
        OrderStatus.driverArrived => 'Driver At Restaurant',
        OrderStatus.pickedUp => 'Picked Up by Driver',
        OrderStatus.delivering => 'Out for Delivery',
        OrderStatus.arrived => 'Driver Has Arrived',
        _ => 'Processing',
      };

  String _statusSubtitle(OrderModel o) => switch (o.status) {
        OrderStatus.placed => 'Waiting for ${o.restaurantName} to accept',
        OrderStatus.awaitingDriver => '${o.restaurantName} accepted — lining up a driver',
        OrderStatus.preparing => '${o.restaurantName} is preparing your order',
        OrderStatus.ready => o.deliveryType == DeliveryType.pickup
            ? 'Head over to collect your order'
            : 'Your driver is on the way to the restaurant',
        OrderStatus.driverArrived => 'Your driver is at the restaurant, picking up your order',
        OrderStatus.pickedUp => 'Your driver has your order',
        OrderStatus.delivering => 'Your order is out for delivery',
        OrderStatus.arrived => 'Your driver is outside',
        _ => '',
      };
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }
}

class _SepLine extends StatelessWidget {
  final bool isDark;

  const _SepLine({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
    );
  }
}

class _StepsRow extends StatelessWidget {
  final List<OrderTimelineStep> steps;

  const _StepsRow({required this.steps});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final segIndex = i ~/ 2;
          final segDone = steps[segIndex].isComplete;
          return Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.only(bottom: 13),
              height: 2,
              decoration: BoxDecoration(
                color: segDone
                    ? AppColors.primary
                    : isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }

        final index = i ~/ 2;
        final step = steps[index];
        final isActive = step.isCurrent;
        final isDone = step.isComplete && !step.isCurrent;

        return Expanded(
          flex: 3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isDone || isActive ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isDone || isActive
                      ? null
                      : Border.all(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFC8D8C8),
                          width: 2,
                        ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 0,
                            spreadRadius: 3,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: isDone
                    ? const Icon(Icons.check, size: 11, color: Colors.white)
                    : isActive
                        ? Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
              ),
              const SizedBox(height: 4),
              Text(
                step.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  fontSize: 7.5,
                  height: 1.1,
                  color: isActive
                      ? AppColors.primary
                      : isDone
                          ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                          : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.label.copyWith(color: color, fontSize: 9),
      ),
    );
  }
}

// ───────────────────────── PAST TAB ─────────────────────────

class _PastTab extends ConsumerWidget {
  final List<OrderModel> orders;

  const _PastTab({required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return const _EmptyState(
        icon: '📋',
        title: 'No past orders yet',
        subtitle: 'Your order history will show up here',
      );
    }

    final unrated = orders.where((o) => o.rating == null).toList();
    final promptOrder = unrated.isEmpty ? null : unrated.first;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (promptOrder != null) _RatePrompt(order: promptOrder),
        ...orders.map((o) => _HistoryCard(order: o, cancelled: false)),
      ],
    );
  }
}

class _RatePrompt extends ConsumerWidget {
  final OrderModel order;

  const _RatePrompt({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface3 : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: _thumbGradient(order.restaurantId),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How was ${order.restaurantName}?',
                  style: AppTypography.subheading.copyWith(color: textPrimary, fontSize: 11),
                ),
                Text(
                  'Order from ${_relativeDate(order.createdAt)}',
                  style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 9),
                ),
                const SizedBox(height: 5),
                Row(
                  children: List.generate(5, (i) {
                    return GestureDetector(
                      onTap: () => ref
                          .read(ordersProvider.notifier)
                          .rateOrder(order.id, i + 1),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Icon(Icons.star_rounded, size: 18, color: AppColors.star),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── CANCELLED TAB ─────────────────────────

class _CancelledTab extends StatelessWidget {
  final List<OrderModel> orders;

  const _CancelledTab({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyState(
        icon: '🚫',
        title: 'No cancelled orders',
        subtitle: 'Cancelled or refunded orders will show up here',
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        ...orders.map((o) => _HistoryCard(order: o, cancelled: true)),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⚡ Cancellation Policy',
                style: AppTypography.caption.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Free cancellation before the restaurant starts preparing. Once preparation begins, cancellation is not available.',
                style: AppTypography.caption.copyWith(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  fontSize: 9,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── SHARED HISTORY CARD ─────────────────────────

class _HistoryCard extends ConsumerWidget {
  final OrderModel order;
  final bool cancelled;

  const _HistoryCard({required this.order, required this.cancelled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final dateFormat = cancelled
        ? DateFormat('MMM d').format(order.createdAt)
        : DateFormat('MMM d, h:mm a').format(order.createdAt);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface3 : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${order.orderNumber} · $dateFormat',
                    style: AppTypography.label.copyWith(color: textMuted, fontSize: 9),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.restaurantName,
                    style: AppTypography.subheading.copyWith(color: textPrimary, fontSize: 13),
                  ),
                ],
              ),
              _Tag(
                label: cancelled ? 'Cancelled' : 'Delivered',
                color: cancelled ? AppColors.danger : AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: _thumbGradient(order.restaurantId),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _itemsSummary(order),
                      style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (cancelled) ...[
                          Text(
                            CurrencyFormatter.compact(order.total),
                            style: AppTypography.subheading.copyWith(
                              color: textMuted,
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (order.isRefunded) _Tag(label: 'Refunded', color: AppColors.primary),
                        ] else ...[
                          Text(
                            CurrencyFormatter.compact(order.total),
                            style: AppTypography.subheading.copyWith(
                              color: AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '· Wallet',
                            style: AppTypography.caption.copyWith(color: textMuted, fontSize: 9),
                          ),
                        ],
                      ],
                    ),
                    if (!cancelled && order.rating != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: i < order.rating! ? AppColors.star : textMuted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'You rated ${order.rating}',
                            style: AppTypography.caption.copyWith(color: textMuted, fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                    if (cancelled && order.cancelReason != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        cancelled && order.cancelReason!.startsWith('Cancelled')
                            ? order.cancelReason!
                            : 'Reason: ${order.cancelReason}',
                        style: AppTypography.caption.copyWith(color: textMuted, fontSize: 9),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: cancelled ? 'Try Again' : 'Reorder',
                  icon: Icons.replay_rounded,
                  primary: true,
                  onTap: () => _reorder(context, ref),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionButton(
                  label: cancelled ? 'View Details' : 'Receipt',
                  icon: cancelled ? null : Icons.receipt_long_outlined,
                  primary: false,
                  onTap: () => _showDetails(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reorder(BuildContext context, WidgetRef ref) async {
    if (order.items.isEmpty) return;
    // First item decides whether the restaurant-switch confirmation fires;
    // the rest are added directly afterward (cart guaranteed single-restaurant
    // by that point).
    final firstItem = order.items.first;
    final added = await addToCartWithRestaurantGuard(
      context,
      ref,
      firstItem.item,
      note: firstItem.note,
      newRestaurantName: order.restaurantName,
    );
    if (!added) return;

    final cart = ref.read(cartProvider.notifier);
    for (var i = 1; i < firstItem.quantity; i++) {
      cart.addItem(firstItem.item, note: firstItem.note);
    }
    for (final ci in order.items.skip(1)) {
      for (var i = 0; i < ci.quantity; i++) {
        cart.addItem(ci.item, note: ci.note);
      }
    }
    if (context.mounted) UniToast.show(context, 'Added ${order.restaurantName} items to cart');
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReceiptSheet(order: order),
    );
  }
}

// ───────────────────────── RECEIPT SHEET ─────────────────────────

class _ReceiptSheet extends StatelessWidget {
  final OrderModel order;

  const _ReceiptSheet({required this.order});

  Future<File> _buildReceiptPdf() async {
    final date = DateFormat('MMM d, yyyy  h:mm a').format(order.createdAt);
    final doc = pw.Document();

    const green = PdfColor.fromInt(0xFF2E7D32);
    const lightGreen = PdfColor.fromInt(0xFFE8F5E9);
    const grey = PdfColor.fromInt(0xFF757575);
    const divider = PdfColor.fromInt(0xFFE0E0E0);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 56),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: const pw.BoxDecoration(color: green),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'UNI EATS',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'UDST Campus · Doha, Qatar',
                        style: const pw.TextStyle(color: const PdfColor.fromInt(0xCCFFFFFF), fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'RECEIPT',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${order.orderNumber}',
                        style: const pw.TextStyle(color: const PdfColor.fromInt(0xCCFFFFFF), fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Order meta
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: lightGreen,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfMeta('Restaurant', order.restaurantName),
                  _pdfMeta('Date', date),
                  _pdfMeta('Type',
                      order.deliveryType == DeliveryType.delivery ? 'Delivery' : 'Pickup'),
                  _pdfMeta('Payment', 'Uni Eats Wallet'),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Items table header
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              color: const PdfColor.fromInt(0xFFF5F5F5),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text('ITEM',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: grey)),
                  ),
                  pw.SizedBox(
                    width: 40,
                    child: pw.Text('QTY',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: grey),
                        textAlign: pw.TextAlign.center),
                  ),
                  pw.SizedBox(
                    width: 70,
                    child: pw.Text('PRICE',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: grey),
                        textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
            ),

            // Items
            ...order.items.asMap().entries.map((e) {
              final ci = e.value;
              final isEven = e.key.isEven;
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                color: isEven ? PdfColors.white : const PdfColor.fromInt(0xFFFAFAFA),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text(ci.item.name,
                          style: const pw.TextStyle(fontSize: 11)),
                    ),
                    pw.SizedBox(
                      width: 40,
                      child: pw.Text('× ${ci.quantity}',
                          style: const pw.TextStyle(fontSize: 11),
                          textAlign: pw.TextAlign.center),
                    ),
                    pw.SizedBox(
                      width: 70,
                      child: pw.Text(CurrencyFormatter.format(ci.total),
                          style: const pw.TextStyle(fontSize: 11),
                          textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              );
            }),

            pw.Divider(color: divider, thickness: 1),
            pw.SizedBox(height: 8),

            // Totals
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12),
              child: pw.Column(
                children: [
                  _pdfTotalRow('Subtotal', CurrencyFormatter.format(order.subtotal), isMain: false),
                  pw.SizedBox(height: 4),
                  _pdfTotalRow('Delivery Fee', CurrencyFormatter.format(order.deliveryFee), isMain: false),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: divider, thickness: 1),
                  pw.SizedBox(height: 8),
                  _pdfTotalRow('TOTAL', CurrencyFormatter.format(order.total), isMain: true),
                ],
              ),
            ),

            pw.SizedBox(height: 32),
            pw.Divider(color: divider),
            pw.SizedBox(height: 12),

            // Footer
            pw.Center(
              child: pw.Text(
                'Thank you for ordering with Uni Eats!',
                style: const pw.TextStyle(fontSize: 11, color: grey),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'For support: support@unieats.qa',
                style: const pw.TextStyle(fontSize: 9, color: grey),
              ),
            ),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/receipt_${order.id}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  pw.Widget _pdfMeta(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF4CAF50))),
          pw.SizedBox(height: 2),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      );

  pw.Widget _pdfTotalRow(String label, String value, {required bool isMain}) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                fontSize: isMain ? 13 : 11,
                fontWeight: isMain ? pw.FontWeight.bold : pw.FontWeight.normal,
              )),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: isMain ? 13 : 11,
                fontWeight: isMain ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: isMain ? const PdfColor.fromInt(0xFF2E7D32) : PdfColors.black,
              )),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final surface = isDark ? AppColors.darkSurface3 : AppColors.lightSurface;
    final date = DateFormat('MMM d, yyyy  h:mm a').format(order.createdAt);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receipt',
                        style: AppTypography.heading.copyWith(color: textPrimary, fontSize: 18),
                      ),
                      Text(
                        'Order ${order.orderNumber}',
                        style: AppTypography.caption.copyWith(color: textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: textMuted, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Scrollable receipt body
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  // Restaurant + status
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: _thumbGradient(order.restaurantId),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.restaurantName,
                                style: AppTypography.subheading.copyWith(color: Colors.white, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                date,
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Tag(
                          label: order.deliveryType == DeliveryType.delivery ? 'Delivery' : 'Pickup',
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Items
                  _ReceiptSection(
                    title: 'Items',
                    isDark: isDark,
                    child: Column(
                      children: order.items.map((ci) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                ci.item.name,
                                style: AppTypography.body.copyWith(color: textPrimary, fontSize: 12),
                              ),
                            ),
                            Text(
                              '× ${ci.quantity}',
                              style: AppTypography.caption.copyWith(color: textMuted, fontSize: 11),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              CurrencyFormatter.format(ci.total),
                              style: AppTypography.subheading.copyWith(color: textPrimary, fontSize: 12),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Totals
                  _ReceiptSection(
                    title: 'Summary',
                    isDark: isDark,
                    child: Column(
                      children: [
                        _ReceiptRow(label: 'Subtotal', value: CurrencyFormatter.format(order.subtotal), muted: true, textPrimary: textPrimary, textSecondary: textSecondary),
                        const SizedBox(height: 4),
                        _ReceiptRow(label: 'Delivery Fee', value: CurrencyFormatter.format(order.deliveryFee), muted: true, textPrimary: textPrimary, textSecondary: textSecondary),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
                        ),
                        const SizedBox(height: 8),
                        _ReceiptRow(label: 'Total', value: CurrencyFormatter.format(order.total), muted: false, textPrimary: textPrimary, textSecondary: textSecondary),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Payment
                  _ReceiptSection(
                    title: 'Payment',
                    isDark: isDark,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: AppColors.walletGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Noqoody',
                            style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 9),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Uni Eats Wallet',
                          style: AppTypography.body.copyWith(color: textPrimary, fontSize: 12),
                        ),
                        const Spacer(),
                        Text(
                          CurrencyFormatter.format(order.total),
                          style: AppTypography.subheading.copyWith(color: AppColors.primary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  if (order.cancelReason != null) ...[
                    const SizedBox(height: 10),
                    _ReceiptSection(
                      title: 'Cancellation',
                      isDark: isDark,
                      child: Text(
                        order.cancelReason!,
                        style: AppTypography.caption.copyWith(color: AppColors.danger, fontSize: 11),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Download button
                  GestureDetector(
                    onTap: () async {
                      final file = await _buildReceiptPdf();
                      await Share.shareXFiles(
                        [XFile(file.path, mimeType: 'application/pdf')],
                        subject: 'Uni Eats Receipt — Order ${order.orderNumber}',
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, AppColors.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Download Receipt',
                            style: AppTypography.button.copyWith(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptSection extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isDark;

  const _ReceiptSection({required this.title, required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTypography.label.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              fontSize: 9,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;
  final Color textPrimary;
  final Color textSecondary;

  const _ReceiptRow({
    required this.label,
    required this.value,
    required this.muted,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: muted
              ? AppTypography.caption.copyWith(color: textSecondary, fontSize: 12)
              : AppTypography.subheading.copyWith(color: textPrimary, fontSize: 13),
        ),
        Text(
          value,
          style: muted
              ? AppTypography.body.copyWith(color: textPrimary, fontSize: 12)
              : AppTypography.subheading.copyWith(color: AppColors.primary, fontSize: 14),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool primary;
  final bool danger;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = primary
        ? AppColors.primary
        : danger
            ? AppColors.danger.withOpacity(0.1)
            : isDark
                ? AppColors.darkSurface2
                : AppColors.lightSurface2;

    final fgColor = primary
        ? Colors.white
        : danger
            ? AppColors.danger
            : isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: primary
              ? null
              : Border.all(
                  color: danger
                      ? AppColors.danger.withOpacity(0.3)
                      : isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: fgColor),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: fgColor,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── EMPTY STATE ─────────────────────────

class _EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;

  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTypography.subheading.copyWith(color: textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── HELPERS ─────────────────────────

String _itemsSummary(OrderModel order) {
  if (order.items.length == 1) {
    final ci = order.items.first;
    return '${ci.item.name} × ${ci.quantity}';
  }
  return order.items.map((ci) => ci.item.name).join(', ');
}

String _relativeDate(DateTime date) {
  final now = DateTime.now();
  final diff = DateTime(now.year, now.month, now.day)
      .difference(DateTime(date.year, date.month, date.day))
      .inDays;
  if (diff <= 0) return 'today';
  if (diff == 1) return 'yesterday';
  return '$diff days ago';
}

LinearGradient _thumbGradient(String restaurantId) {
  const gradients = {
    'r001': [Color(0xFF8B4513), Color(0xFF5C2D0A)], // Tim Hortons
    'r002': [Color(0xFF2D4A1E), Color(0xFF1A3010)], // Oakberry
    'r003': [Color(0xFF1A2A3A), Color(0xFF0D1A28)], // Edge Cafe
    'r004': [Color(0xFF4A1A0A), Color(0xFF8B4513)], // Caribou Coffee
  };
  final colors = gradients[restaurantId] ?? [AppColors.primary, AppColors.primaryDark];
  return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors);
}
