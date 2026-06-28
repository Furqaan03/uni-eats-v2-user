import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../campus_map/campus_map_painter.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/pill_nav.dart';
import '../../core/widgets/uni_toast.dart';
import '../../models/order_model.dart';
import '../../services/mock_data_service.dart';
import '../../utils/currency_formatter.dart';
import '../orders/providers/orders_provider.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  final Offset _driverStart = const Offset(0.18, 0.48);
  final Offset _driverEnd = const Offset(0.62, 0.40);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _controller.repeat(reverse: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _currentDriverPosition(double t) {
    return Offset(
      _driverStart.dx + (_driverEnd.dx - _driverStart.dx) * t,
      _driverStart.dy + (_driverEnd.dy - _driverStart.dy) * t +
          0.04 * math.sin(t * math.pi * 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    // This screen is delivery tracking specifically — pickup orders have no
    // driver/route to show, and a stale cancelled/delivered order has no
    // business being displayed here just because it's the only thing in the
    // list. Previously this fell back to `allOrders.first` when nothing was
    // active, which could surface a long-finished or cancelled order as if
    // it were still being tracked. Empty unless there's a real, currently
    // active delivery order.
    final allOrders = ref.watch(ordersProvider);
    final activeDeliveryOrders = allOrders
        .where((o) => o.deliveryType == DeliveryType.delivery && o.isActive)
        .toList();

    if (activeDeliveryOrders.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            'No active deliveries right now.',
            style: AppTypography.body.copyWith(color: textSecondary),
          ),
        ),
      );
    }

    final order = activeDeliveryOrders.firstWhere(
      (o) => o.status == OrderStatus.delivering,
      orElse: () => activeDeliveryOrders.first,
    );

    final isDelivering = order.status == OrderStatus.delivering;
    // `order` is always an active delivery order at this point (cancelled
    // orders never reach here — filtered out above), but the destination/
    // driver marker still only appears once an actual driver has accepted
    // it (driverId set) — before that, there's no real route to show.
    final orderVisibleOnMap = order.driverId != null;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    final driverPos = _currentDriverPosition(_animation.value);
                    return InteractiveViewer(
                      boundaryMargin: const EdgeInsets.all(40),
                      minScale: 0.6,
                      maxScale: 3.0,
                      child: CustomPaint(
                        painter: CampusMapPainter(
                          locations: MockDataService.campusLocations,
                          driverPosition:
                              orderVisibleOnMap && isDelivering ? driverPos : null,
                          destinationPosition:
                              orderVisibleOnMap ? const Offset(0.62, 0.40) : null,
                        ),
                        size: Size.infinite,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: _TrackingTopBar(order: order, isDark: isDark),
          ),
          if (isDelivering)
            Positioned(
              bottom: PillNavBar.height + 16,
              left: 0,
              right: 0,
              child: Center(
                child: _DeliveringToLabel(),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: PillNavBar.height + 16,
            child: _TrackingSheet(
              order: order,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onPickupMyself: () => ref.read(ordersProvider.notifier).switchToPickup(order.id),
              onCancel: () => ref.read(ordersProvider.notifier).cancelOrder(order.id,
                  reason: 'No driver available'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingTopBar extends StatelessWidget {
  final OrderModel order;
  final bool isDark;

  const _TrackingTopBar({required this.order, required this.isDark});

  String get _statusText {
    return switch (order.status) {
      OrderStatus.placed => 'Order confirmed...',
      OrderStatus.awaitingDriver => 'Finding you a driver...',
      OrderStatus.preparing => 'Preparing your order...',
      OrderStatus.ready => 'Ready for pickup',
      OrderStatus.driverArrived => 'Driver is at the restaurant...',
      OrderStatus.pickedUp => 'Picked up, on the way...',
      OrderStatus.delivering => '${order.driverName ?? 'Driver'} is on the way!',
      OrderStatus.arrived => '${order.driverName ?? 'Driver'} has arrived!',
      OrderStatus.delivered => 'Delivered! Enjoy 🎉',
      OrderStatus.cancelled => 'Order cancelled',
    };
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? AppColors.darkSurface3 : Colors.white;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Row(
      children: [
        _RoundIconButton(
          icon: Icons.arrow_back,
          surfaceColor: surfaceColor,
          iconColor: textSecondary,
          onTap: () => context.go('/home'),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Order #${order.id.toUpperCase()}',
                  style: AppTypography.subheading.copyWith(color: textPrimary, fontSize: 13),
                ),
                const SizedBox(height: 1),
                Text(
                  _statusText,
                  style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        _RoundIconButton(
          icon: Icons.more_horiz,
          surfaceColor: surfaceColor,
          iconColor: textSecondary,
          onTap: () => UniToast.show(context, 'More options'),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color surfaceColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.surfaceColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceColor,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 16, color: iconColor),
        ),
      ),
    );
  }
}

class _DeliveringToLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(
        '📍 Delivering to: B3, Room 204',
        style: AppTypography.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _TrackingSheet extends StatelessWidget {
  final OrderModel order;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onPickupMyself;
  final VoidCallback onCancel;

  const _TrackingSheet({
    required this.order,
    required this.textPrimary,
    required this.textSecondary,
    required this.onPickupMyself,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final showDriverCard = order.status == OrderStatus.delivering ||
        order.status == OrderStatus.delivered;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 320),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (order.noDriversAvailable) ...[
              _NoDriversBanner(
                order: order,
                onPickupMyself: onPickupMyself,
                onCancel: onCancel,
              ),
              const SizedBox(height: 10),
            ],
            _EtaCard(order: order),
            if (showDriverCard) ...[
              const SizedBox(height: 10),
              _DriverCard(order: order, isDark: isDark),
            ],
            const SizedBox(height: 14),
            _Timeline(order: order, textPrimary: textPrimary, textMuted: textMuted),
          ],
        ),
      ),
    );
  }
}

class _NoDriversBanner extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onPickupMyself;
  final VoidCallback onCancel;

  const _NoDriversBanner({
    required this.order,
    required this.onPickupMyself,
    required this.onCancel,
  });

  Future<void> _confirmPickup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick up yourself?'),
        content: Text(
          'You\'ll collect the order from ${order.restaurantName} in person. '
          'The delivery fee will be refunded from this order\'s total.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Switch to Pickup'),
          ),
        ],
      ),
    );
    if (confirmed == true) onPickupMyself();
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Order')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed == true) onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No driver is available for this order right now.',
                  style: AppTypography.label.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _confirmCancel(context),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  child: const Text('Cancel Order'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _confirmPickup(context),
                  child: const Text('Pick Up Myself'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EtaCard extends StatelessWidget {
  final OrderModel order;

  const _EtaCard({required this.order});

  @override
  Widget build(BuildContext context) {
    String emoji;
    String label;
    String time;
    String sub;

    final remaining = order.estimatedDelivery != null
        ? order.estimatedDelivery!.difference(DateTime.now()).inMinutes
        : 0;

    switch (order.status) {
      case OrderStatus.placed:
        emoji = '📋';
        label = 'Estimated preparation';
        time = '12 min';
        sub = 'Waiting for restaurant to confirm';
      case OrderStatus.awaitingDriver:
        emoji = '🔎';
        label = 'Finding a driver';
        time = '--';
        sub = 'Restaurant accepted — lining up a driver';
      case OrderStatus.preparing:
      case OrderStatus.ready:
      case OrderStatus.driverArrived:
        emoji = '🍳';
        label = 'Estimated arrival';
        time = '${remaining.clamp(1, 60)} min';
        sub = 'Your order is being prepared';
      case OrderStatus.pickedUp:
      case OrderStatus.delivering:
      case OrderStatus.arrived:
        emoji = '🛵';
        label = 'Arriving in';
        time = '${remaining.clamp(1, 60)} min';
        sub = '${order.driverName ?? 'Your driver'} picked up your order';
      case OrderStatus.delivered:
        emoji = '✅';
        label = 'Delivered at';
        time = DateFormat('h:mm a').format(order.createdAt);
        sub = 'Your order has been delivered!';
      case OrderStatus.cancelled:
        emoji = '❌';
        label = 'Order cancelled';
        time = '--';
        sub = order.cancelReason ?? 'This order was cancelled';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.walletGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(color: Colors.white.withOpacity(0.7), fontSize: 10),
                ),
                Text(
                  time,
                  style: AppTypography.displayMedium.copyWith(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  sub,
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(emoji, style: const TextStyle(fontSize: 28)),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final OrderModel order;
  final bool isDark;

  const _DriverCard({required this.order, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface3 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: AppColors.walletGradient,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('👨‍🎓', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.driverName ?? 'Delivery Partner',
                  style: AppTypography.subheading.copyWith(color: textPrimary, fontSize: 12),
                ),
                Text(
                  'Student Delivery · ⭐ 4.9',
                  style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _DriverActionButton(
                icon: Icons.phone,
                color: AppColors.primary,
                onTap: () => UniToast.show(context, 'Calling ${order.driverName ?? 'driver'}...'),
              ),
              const SizedBox(width: 8),
              _DriverActionButton(
                icon: Icons.chat_bubble_outline,
                color: AppColors.accent,
                onTap: () => UniToast.show(context, 'Opening chat with ${order.driverName ?? 'driver'}...'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DriverActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.15),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final OrderModel order;
  final Color textPrimary;
  final Color textMuted;

  const _Timeline({required this.order, required this.textPrimary, required this.textMuted});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final lineColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final steps = order.timeline;
    final activeIndex = order.isActive ? steps.indexWhere((s) => !s.isComplete) : -1;

    // Keyed by the step's own label (set in FirestoreOrderService._buildTimeline)
    // rather than a fixed-length positional list — the delivery and pickup
    // timelines have different step counts, so a hardcoded index list goes
    // out of sync the moment either one changes.
    final subtitleByLabel = <String, String>{
      'Order Placed': '${order.restaurantName} · ${CurrencyFormatter.format(order.total)}',
      'Finding a Driver': 'Lining up a driver for your order',
      'Preparing': 'Restaurant is making your order',
      'Ready for Pickup': 'Head over to collect your order',
      'Driver Arrived': '${order.driverName ?? 'Your driver'} is at the restaurant',
      'Picked Up': 'Your order has been collected',
      'Out for Delivery': '${order.driverName ?? 'Your driver'} has your order and is on the way',
      'Driver Has Arrived': '${order.driverName ?? 'Your driver'} is outside — head out to meet them',
      'Delivered': 'Enjoy your meal! 🎉',
    };

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineItem(
            title: steps[i].label,
            subtitle: subtitleByLabel[steps[i].label] ?? '',
            time: DateFormat('h:mm a').format(order.createdAt.add(Duration(minutes: i * 6))),
            state: steps[i].isComplete
                ? _TimelineState.done
                : i == activeIndex
                    ? _TimelineState.active
                    : _TimelineState.pending,
            showLine: i < steps.length - 1,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textMuted: textMuted,
            lineColor: lineColor,
          ),
      ],
    );
  }
}

enum _TimelineState { done, active, pending }

class _TimelineItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final _TimelineState state;
  final bool showLine;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color lineColor;

  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.state,
    required this.showLine,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = state == _TimelineState.pending ? textMuted : textPrimary;
    final subColor = state == _TimelineState.pending ? textMuted : textSecondary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                _TimelineDot(state: state, lineColor: lineColor),
                if (showLine) Expanded(child: Container(width: 2, color: lineColor)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.subheading.copyWith(color: titleColor, fontSize: 12),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(color: subColor, fontSize: 10),
                  ),
                  if (state != _TimelineState.pending) ...[
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
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
}

class _TimelineDot extends StatelessWidget {
  final _TimelineState state;
  final Color lineColor;

  const _TimelineDot({required this.state, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _TimelineState.done:
        return Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 12, color: Colors.white),
        );
      case _TimelineState.active:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 0, spreadRadius: 4),
            ],
          ),
          alignment: Alignment.center,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        );
      case _TimelineState.pending:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: lineColor, width: 2),
          ),
        );
    }
  }
}
