import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/order_timeline.dart';
import '../../models/order_model.dart';
import '../../utils/currency_formatter.dart';
import 'providers/orders_provider.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final activeOrders = ref.watch(activeOrdersProvider);
    final pastOrders = ref.watch(pastOrdersProvider);
    final cancelledOrders = <OrderModel>[]; // Mock: no cancelled orders yet

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Orders',
          style: AppTypography.heading.copyWith(color: textPrimary),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.w800),
          unselectedLabelStyle: AppTypography.caption,
          labelColor: AppColors.primary,
          unselectedLabelColor: textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Past'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OrderList(orders: activeOrders, isActive: true),
          _OrderList(orders: pastOrders, isActive: false),
          _OrderList(orders: cancelledOrders, isActive: false),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<OrderModel> orders;
  final bool isActive;

  const _OrderList({required this.orders, required this.isActive});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
        child: Text('No orders here yet'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _OrderCard(order: order, isActive: isActive);
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final bool isActive;

  const _OrderCard({required this.order, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.restaurantName,
                style: AppTypography.subheading.copyWith(color: textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.statusLabel,
                  style: AppTypography.caption.copyWith(
                    color: _statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'} · ${order.deliveryType.name}',
            style: AppTypography.caption.copyWith(color: textSecondary),
          ),
          const SizedBox(height: 12),
          if (order.timeline.isNotEmpty) OrderTimeline(steps: order.timeline),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                CurrencyFormatter.format(order.total),
                style: AppTypography.subheading.copyWith(color: AppColors.primary),
              ),
              if (isActive && order.status == OrderStatus.delivering)
                ElevatedButton(
                  onPressed: () => context.go('/tracking'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(0, 34),
                  ),
                  child: const Text('Track'),
                ),
              if (!isActive)
                Row(
                  children: [
                    _ActionButton(label: 'Reorder', onTap: () {}),
                    const SizedBox(width: 8),
                    _ActionButton(label: 'Receipt', onTap: () {}),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color get _statusColor {
    return switch (order.status) {
      OrderStatus.delivered => AppColors.primary,
      OrderStatus.cancelled => AppColors.danger,
      OrderStatus.delivering => AppColors.accent,
      _ => AppColors.star,
    };
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
