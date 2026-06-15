import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../campus_map/campus_map_painter.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/pill_nav.dart';
import '../../models/order_model.dart';
import '../../services/mock_data_service.dart';
import '../../utils/currency_formatter.dart';

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

    final activeOrder = MockDataService.orders.firstWhere(
      (o) => o.status == OrderStatus.delivering,
      orElse: () => MockDataService.orders.first,
    ) as OrderModel;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final driverPos = _currentDriverPosition(_animation.value);

          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: InteractiveViewer(
                      boundaryMargin: const EdgeInsets.all(40),
                      minScale: 0.6,
                      maxScale: 3.0,
                      child: CustomPaint(
                        painter: CampusMapPainter(
                          locations: MockDataService.campusLocations,
                          driverPosition: driverPos,
                          destinationPosition: const Offset(0.62, 0.40),
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                right: 16,
                child: _TrackingAppBar(
                  title: 'Order #${activeOrder.id.toUpperCase().substring(0, 6)}',
                  subtitle: 'Driver is on the way',
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: PillNavBar.height + 16,
                child: _TrackingSheet(
                  order: activeOrder,
                  driverPos: driverPos,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrackingAppBar extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TrackingAppBar({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface.withOpacity(0.95) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.subheading.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            subtitle,
            style: AppTypography.caption.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _TrackingSheet extends StatelessWidget {
  final OrderModel order;
  final Offset driverPos;
  final Color textPrimary;
  final Color textSecondary;

  const _TrackingSheet({
    required this.order,
    required this.driverPos,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delivery_dining,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Driver · Ahmed',
                      style: AppTypography.subheading.copyWith(color: textPrimary),
                    ),
                    Text(
                      'Estimated arrival: 8 min',
                      style: AppTypography.caption.copyWith(color: textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.phone, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Order from ${order.restaurantName}',
            style: AppTypography.body.copyWith(color: textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '${order.items.length} items · ${CurrencyFormatter.format(order.total)}',
            style: AppTypography.caption.copyWith(color: textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Message Driver'),
            ),
          ),
        ],
      ),
    );
  }
}
