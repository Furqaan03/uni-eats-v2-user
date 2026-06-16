import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/uni_toast.dart';
import '../../models/wallet_transaction_model.dart';
import '../../services/mock_data_service.dart';
import '../../utils/currency_formatter.dart';
import '../home/providers/notifications_provider.dart';
import 'providers/wallet_provider.dart';

enum _WalletTab { overview, insights, transactions }

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  _WalletTab _tab = _WalletTab.overview;
  bool _isFrozen = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final balance = ref.watch(walletBalanceProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  _CircleButton(
                    icon: Icons.arrow_back,
                    isDark: isDark,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'My Wallet',
                    style: AppTypography.heading.copyWith(color: textPrimary, fontSize: 18),
                  ),
                  const Spacer(),
                  if (_isFrozen)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '🔒 FROZEN',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    _WalletCard(balance: balance, isFrozen: _isFrozen),
                    _QuickActions(
                      isDark: isDark,
                      isFrozen: _isFrozen,
                      onTopUp: () => _showTopUpSheet(context, ref),
                      onTransfer: () => UniToast.show(context, 'Transfer feature coming soon'),
                      onStatements: () => setState(() => _tab = _WalletTab.transactions),
                      onFreeze: () {
                        setState(() => _isFrozen = !_isFrozen);
                        UniToast.show(
                          context,
                          _isFrozen ? '🔒 Card frozen — payments blocked' : '✓ Card unfrozen',
                        );
                      },
                    ),
                    _QPayButton(onTap: () => _showTopUpSheet(context, ref)),
                    _SegmentedTabs(
                      selected: _tab,
                      isDark: isDark,
                      onChanged: (t) => setState(() => _tab = t),
                    ),
                    const SizedBox(height: 6),
                    switch (_tab) {
                      _WalletTab.overview => _OverviewTab(
                          isDark: isDark,
                          onTopUpAmount: (amount) => _showTopUpSheet(context, ref, initialAmount: amount),
                        ),
                      _WalletTab.insights => _InsightsTab(isDark: isDark),
                      _WalletTab.transactions => _TransactionsTab(
                          isDark: isDark,
                          textSecondary: textSecondary,
                        ),
                    },
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTopUpSheet(BuildContext context, WidgetRef ref, {double? initialAmount}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopUpSheet(
        initialAmount: initialAmount,
        onTopUp: (amount) {
          ref.read(walletBalanceProvider.notifier).topUp(amount);
          ref.read(notificationsProvider.notifier).addNotification(
                NotificationItem(
                  emoji: '💳',
                  title: 'Wallet Top-Up',
                  subtitle: 'QAR ${amount.toStringAsFixed(2)} added successfully',
                  route: '/wallet',
                  navType: NotifNavType.push,
                ),
              );
        },
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.darkSurface3 : Colors.white,
      shape: const CircleBorder(),
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final double balance;
  final bool isFrozen;

  const _WalletCard({required this.balance, required this.isFrozen});

  @override
  Widget build(BuildContext context) {
    final user = MockDataService.currentUser;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      height: 160,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF0A6B1E), AppColors.primaryDark, Color(0xFF052E11)],
          stops: [0.0, 0.4, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.32), blurRadius: 44, offset: const Offset(0, 14)),
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Icon(Icons.account_balance_wallet_outlined, size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'UNI EATS',
                      style: AppTypography.label.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.wifi, size: 18, color: Colors.white.withOpacity(0.7)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 22,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFE8C84A), Color(0xFFC9A82A)]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BALANCE',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 8,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.compact(balance),
                          style: AppTypography.heading.copyWith(
                            color: Colors.white,
                            fontSize: 19,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '••••  ••••  ••••  4821',
                  style: AppTypography.body.copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CARD HOLDER',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 6,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          user.name.toUpperCase(),
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'VALID THRU',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 6,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          '12/27',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isFrozen)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, size: 26, color: Colors.white),
                    const SizedBox(height: 6),
                    Text(
                      'Card Frozen',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool isDark;
  final bool isFrozen;
  final VoidCallback onTopUp;
  final VoidCallback onTransfer;
  final VoidCallback onStatements;
  final VoidCallback onFreeze;

  const _QuickActions({
    required this.isDark,
    required this.isFrozen,
    required this.onTopUp,
    required this.onTransfer,
    required this.onStatements,
    required this.onFreeze,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionButton(
              icon: Icons.add,
              iconColor: AppColors.primary,
              bgColor: AppColors.primary.withOpacity(0.15),
              label: 'Top Up',
              isDark: isDark,
              onTap: onTopUp,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.send_outlined,
              iconColor: AppColors.accent,
              bgColor: AppColors.accent.withOpacity(0.12),
              label: 'Transfer',
              isDark: isDark,
              onTap: onTransfer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.receipt_long_outlined,
              iconColor: AppColors.primary,
              bgColor: AppColors.primary.withOpacity(0.15),
              label: 'Statements',
              isDark: isDark,
              onTap: onStatements,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickActionButton(
              icon: isFrozen ? Icons.lock_open_outlined : Icons.lock_outline,
              iconColor: AppColors.accent,
              bgColor: AppColors.accent.withOpacity(0.12),
              label: isFrozen ? 'Unfreeze' : 'Freeze',
              isDark: isDark,
              onTap: onFreeze,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;

    return Material(
      color: isDark ? AppColors.darkSurface3 : Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black.withOpacity(0.06),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QPayButton extends StatelessWidget {
  final VoidCallback onTap;

  const _QPayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8B0000), Color(0xFFC0392B)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.credit_card, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pay via QPay',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Top up instantly · Qatar bank cards',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: Colors.white.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final _WalletTab selected;
  final bool isDark;
  final ValueChanged<_WalletTab> onChanged;

  const _SegmentedTabs({required this.selected, required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    const labels = {
      _WalletTab.overview: 'Overview',
      _WalletTab.insights: 'Insights',
      _WalletTab.transactions: 'Transactions',
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface3 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
      ),
      child: Row(
        children: _WalletTab.values.map((tab) {
          final isSelected = tab == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[tab]!,
                  style: AppTypography.caption.copyWith(
                    color: isSelected ? Colors.white : textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  final bool isDark;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _RowCard({
    required this.isDark,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface3 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;

  const _SectionLabel({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.label.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final bool isDark;
  final ValueChanged<double> onTopUpAmount;

  const _OverviewTab({required this.isDark, required this.onTopUpAmount});

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Row(
                children: [
                  _SmallCircleButton(
                    icon: Icons.chevron_left,
                    isDark: isDark,
                    onTap: () => UniToast.show(context, 'Previous month'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'June 2026',
                    style: AppTypography.subheading.copyWith(color: textPrimary, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  _SmallCircleButton(icon: Icons.chevron_right, isDark: isDark, muted: true, onTap: () {}),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(124.50),
                    style: AppTypography.subheading.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '↓ 12% vs May',
                    style: AppTypography.caption.copyWith(color: textMuted, fontSize: 8),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _RowCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '6-MONTH SPEND (QAR)',
                style: AppTypography.caption.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                ),
              ),
              const SizedBox(height: 8),
              const _BarChart(),
            ],
          ),
        ),
        _RowCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SPENDING BREAKDOWN',
                style: AppTypography.caption.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _DonutChart(isDark: isDark),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        _BreakdownRow(color: AppColors.accent, label: 'Food', amount: 'QAR 60', pct: '48%', isDark: isDark),
                        const SizedBox(height: 6),
                        _BreakdownRow(color: AppColors.primary, label: 'Coffee', amount: 'QAR 48', pct: '38%', isDark: isDark),
                        const SizedBox(height: 6),
                        _BreakdownRow(color: AppColors.primaryDark, label: 'Healthy', amount: 'QAR 16.50', pct: '14%', isDark: isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _BudgetTracker(isDark: isDark),
        _SectionLabel(text: 'Quick Top-up', isDark: isDark),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final amount in [20.0, 50.0, 100.0, 200.0])
                _TopupChip(
                  label: 'QAR ${amount.toStringAsFixed(0)}',
                  isDark: isDark,
                  onTap: () => onTopUpAmount(amount),
                ),
              _TopupChip(
                label: 'Custom',
                isDark: isDark,
                onTap: () => onTopUpAmount(50),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SmallCircleButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final bool muted;
  final VoidCallback onTap;

  const _SmallCircleButton({required this.icon, required this.isDark, required this.onTap, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: muted
              ? (isDark ? AppColors.darkSurface3 : AppColors.lightSurface2)
              : AppColors.primary.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 13,
          color: muted ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted) : AppColors.primary,
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart();

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
  static const _heights = [0.45, 0.60, 0.80, 0.55, 1.0, 0.70];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? AppColors.darkSurface2 : const Color(0xFFE0EBE0);
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _months.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(color: barBg, borderRadius: BorderRadius.circular(4)),
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: _heights[i],
                          widthFactor: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: i == _months.length - 1 ? AppColors.primary.withOpacity(0.45) : AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _months[i],
                      style: AppTypography.caption.copyWith(
                        color: i == _months.length - 1 ? AppColors.primary : textMuted,
                        fontWeight: i == _months.length - 1 ? FontWeight.w700 : FontWeight.normal,
                        fontSize: 7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  final bool isDark;

  const _DonutChart({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;

    return Container(
      width: 90,
      height: 90,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            AppColors.accent, AppColors.accent,
            AppColors.primary, AppColors.primary,
            AppColors.primaryDark, AppColors.primaryDark,
          ],
          stops: [0.0, 0.48, 0.48, 0.864, 0.864, 1.0],
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface3 : Colors.white,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('QAR', style: AppTypography.caption.copyWith(color: textPrimary, fontWeight: FontWeight.w900, fontSize: 11)),
            Text('124', style: AppTypography.subheading.copyWith(color: textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final Color color;
  final String label;
  final String amount;
  final String pct;
  final bool isDark;

  const _BreakdownRow({required this.color, required this.label, required this.amount, required this.pct, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 9)),
        const Spacer(),
        Text(amount, style: AppTypography.caption.copyWith(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 10)),
        const SizedBox(width: 4),
        Text(pct, style: AppTypography.caption.copyWith(color: textMuted, fontSize: 8)),
      ],
    );
  }
}

class _BudgetTracker extends StatelessWidget {
  final bool isDark;

  const _BudgetTracker({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final barBg = isDark ? AppColors.darkSurface2 : const Color(0xFFE0EBE0);

    return _RowCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MONTHLY BUDGET',
                      style: AppTypography.caption.copyWith(color: textSecondary, fontWeight: FontWeight.w700, fontSize: 9),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          CurrencyFormatter.format(124.50),
                          style: AppTypography.subheading.copyWith(color: textPrimary, fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        const SizedBox(width: 4),
                        Text('/ 200', style: AppTypography.caption.copyWith(color: textMuted, fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => UniToast.show(context, 'Edit budget'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Text('Edit', style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 9)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: barBg),
                  FractionallySizedBox(
                    widthFactor: 0.6225,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('62% used', style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 8)),
              Text('QAR 75.50 remaining', style: AppTypography.caption.copyWith(color: textMuted, fontSize: 8)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "✓ On track — you're spending less than last June",
              style: AppTypography.caption.copyWith(color: AppColors.primary, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopupChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _TopupChip({required this.label, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface3 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Text(label, style: AppTypography.caption.copyWith(color: textSecondary, fontWeight: FontWeight.w700, fontSize: 10)),
      ),
    );
  }
}

class _InsightsTab extends StatelessWidget {
  final bool isDark;

  const _InsightsTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _InsightCard(emoji: '☕', value: 'Tim Hortons', label: 'Most visited · 9 orders', isDark: isDark)),
              const SizedBox(width: 8),
              Expanded(child: _InsightCard(emoji: '🕐', value: '12 – 1 PM', label: 'Peak order time', isDark: isDark)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _InsightCard(emoji: '📦', value: '14 orders', label: 'This month total', isDark: isDark)),
              const SizedBox(width: 8),
              Expanded(child: _InsightCard(emoji: '💰', value: 'QAR 8.89', label: 'Avg per order', isDark: isDark)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _HeatmapCard(isDark: isDark),
        _TopRestaurantsCard(isDark: isDark),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary.withOpacity(0.1), AppColors.primaryDark.withOpacity(0.15)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💡 Spending Insight', style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 10)),
              const SizedBox(height: 4),
              Text(
                'You spend 68% more on Fridays. Setting a Friday budget limit could save you ~QAR 15/month.',
                style: AppTypography.caption.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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

class _InsightCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final bool isDark;

  const _InsightCard({required this.emoji, required this.value, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface3 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.subheading.copyWith(color: textPrimary, fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(height: 1),
          Text(label, style: AppTypography.caption.copyWith(color: textMuted, fontSize: 8)),
        ],
      ),
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  final bool isDark;

  const _HeatmapCard({required this.isDark});

  static const _levels = [
    [2, 1, 3, 0, 4, 1, 0],
    [1, 3, 2, 4, 3, 0, 0],
    [2, 1, 0, 2, 3, 1, 0],
  ];

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return _RowCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ACTIVITY HEATMAP — JUNE', style: AppTypography.caption.copyWith(color: textSecondary, fontWeight: FontWeight.w700, fontSize: 9)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in days)
                Expanded(
                  child: Center(
                    child: Text(d, style: AppTypography.caption.copyWith(color: textMuted, fontSize: 7)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          for (final week in _levels)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  for (final level in week)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _heatColor(level, isDark),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Less', style: AppTypography.caption.copyWith(color: textMuted, fontSize: 8)),
              Row(
                children: [
                  for (var i = 0; i <= 4; i++)
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: _heatColor(i, isDark), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                ],
              ),
              Text('More', style: AppTypography.caption.copyWith(color: textMuted, fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }

  Color _heatColor(int level, bool isDark) {
    switch (level) {
      case 0:
        return isDark ? AppColors.darkSurface2 : const Color(0xFFE8F0E8);
      case 1:
        return AppColors.primary.withOpacity(0.15);
      case 2:
        return AppColors.primary.withOpacity(0.35);
      case 3:
        return AppColors.primary.withOpacity(0.6);
      default:
        return AppColors.primary;
    }
  }
}

class _TopRestaurantsCard extends StatelessWidget {
  final bool isDark;

  const _TopRestaurantsCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return _RowCard(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('TOP RESTAURANTS THIS MONTH', style: AppTypography.caption.copyWith(color: textSecondary, fontWeight: FontWeight.w700, fontSize: 9)),
          ),
          const SizedBox(height: 6),
          _RestaurantRankRow(rank: '🥇', emoji: '☕', name: 'Tim Hortons', barFraction: 1.0, amount: 'QAR 60', orders: '9 orders', isDark: isDark),
          _RestaurantRankRow(rank: '🥈', emoji: '🫐', name: 'Oakberry', barFraction: 0.64, amount: 'QAR 38', orders: '3 orders', isDark: isDark),
          _RestaurantRankRow(rank: '🥉', emoji: '🍕', name: 'Edge Cafe', barFraction: 0.44, amount: 'QAR 26.50', orders: '2 orders', isDark: isDark),
        ],
      ),
    );
  }
}

class _RestaurantRankRow extends StatelessWidget {
  final String rank;
  final String emoji;
  final String name;
  final double barFraction;
  final String amount;
  final String orders;
  final bool isDark;

  const _RestaurantRankRow({
    required this.rank,
    required this.emoji,
    required this.name,
    required this.barFraction,
    required this.amount,
    required this.orders,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final barBg = isDark ? AppColors.darkSurface2 : const Color(0xFFE0EBE0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 20, child: Text(rank, style: const TextStyle(fontSize: 14), textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.caption.copyWith(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 11)),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      children: [
                        Container(color: barBg),
                        FractionallySizedBox(
                          widthFactor: barFraction,
                          child: Container(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: AppTypography.caption.copyWith(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 10)),
              Text(orders, style: AppTypography.caption.copyWith(color: textMuted, fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  final bool isDark;
  final Color textSecondary;

  const _TransactionsTab({required this.isDark, required this.textSecondary});

  @override
  Widget build(BuildContext context) {
    final transactions = MockDataService.walletTransactions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        _SectionLabel(text: 'Statements', isDark: isDark),
        _StatementRow(month: 'June 2026', detail: '14 transactions · QAR 124.50', isDark: isDark),
        _StatementRow(month: 'May 2026', detail: '18 transactions · QAR 142.00', isDark: isDark),
        _StatementRow(month: 'April 2026', detail: '11 transactions · QAR 98.50', isDark: isDark),
        const SizedBox(height: 4),
        _SectionLabel(text: 'Recent Transactions', isDark: isDark),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface3 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
          ),
          child: Column(
            children: [
              for (var i = 0; i < transactions.length; i++) ...[
                _TransactionTile(tx: transactions[i], isDark: isDark),
                if (i < transactions.length - 1)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: GestureDetector(
              onTap: () => UniToast.show(context, 'Loading older transactions…'),
              child: Text(
                'Load older transactions →',
                style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatementRow extends StatelessWidget {
  final String month;
  final String detail;
  final bool isDark;

  const _StatementRow({required this.month, required this.detail, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return GestureDetector(
      onTap: () => UniToast.show(context, 'Downloading $month statement…'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface3 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: const Icon(Icons.description_outlined, size: 15, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(month, style: AppTypography.caption.copyWith(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 11)),
                  Text(detail, style: AppTypography.caption.copyWith(color: textMuted, fontSize: 9)),
                ],
              ),
            ),
            Text('PDF', style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransactionModel tx;
  final bool isDark;

  const _TransactionTile({required this.tx, required this.isDark});

  String _emojiFor(WalletTransactionModel tx) {
    if (tx.type == TransactionType.topUp) return '⬆️';
    if (tx.type == TransactionType.refund) return '↩️';
    final desc = (tx.description ?? '').toLowerCase();
    if (desc.contains('hortons') || desc.contains('caribou') || desc.contains('coffee')) return '☕';
    if (desc.contains('oakberry') || desc.contains('healthy')) return '🥗';
    if (desc.contains('edge') || desc.contains('pizza')) return '🍕';
    return '🍽️';
  }

  String _formatTime(DateTime ts) {
    final now = DateTime.now();
    final local = ts.toLocal();
    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = local.year == yesterday.year && local.month == yesterday.month && local.day == yesterday.day;

    final time = DateFormat('h:mm a').format(local);
    if (isToday) return 'Today · $time';
    if (isYesterday) return 'Yesterday · $time';
    return '${DateFormat('MMM d').format(local)} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final iconBg = isDark ? AppColors.darkSurface2 : const Color(0xFFF0F5F0);

    return InkWell(
      onTap: () => UniToast.show(context, tx.description ?? (isCredit ? 'Top up' : 'Payment')),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(_emojiFor(tx), style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description ?? (isCredit ? 'Top up' : 'Payment'),
                    style: AppTypography.caption.copyWith(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                  Text(_formatTime(tx.timestamp), style: AppTypography.caption.copyWith(color: textMuted, fontSize: 9)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '−'} ${CurrencyFormatter.format(tx.amount)}',
                  style: AppTypography.caption.copyWith(
                    color: isCredit ? AppColors.primary : AppColors.danger,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopUpSheet extends StatefulWidget {
  final ValueChanged<double> onTopUp;
  final double? initialAmount;

  const _TopUpSheet({required this.onTopUp, this.initialAmount});

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  late double _selectedAmount;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _selectedAmount = widget.initialAmount ?? 50;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Consumer(
      builder: (context, ref, _) {
        final currentBalance = ref.watch(walletBalanceProvider);
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface3 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Top Up Wallet',
                style: AppTypography.subheading.copyWith(color: textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(
                  style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 10),
                  children: [
                    const TextSpan(text: 'Current balance: '),
                    TextSpan(
                      text: CurrencyFormatter.format(currentBalance),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text('QAR', style: AppTypography.subheading.copyWith(color: textSecondary, fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedAmount.toStringAsFixed(0),
                        style: AppTypography.heading.copyWith(color: textPrimary, fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [20.0, 50.0, 100.0, 200.0].map((amount) {
                  final selected = _selectedAmount == amount;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAmount = amount),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary.withOpacity(0.15) : (isDark ? AppColors.darkSurface2 : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                      ),
                      child: Text(
                        amount.toStringAsFixed(0),
                        style: AppTypography.caption.copyWith(
                          color: selected ? AppColors.primary : textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: _processing
                        ? null
                        : () async {
                            setState(() => _processing = true);
                            await Future.delayed(const Duration(milliseconds: 700));
                            if (!mounted) return;
                            widget.onTopUp(_selectedAmount);
                            Navigator.pop(context);
                            UniToast.show(context, '✓ ${CurrencyFormatter.format(_selectedAmount)} added to wallet');
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: AppColors.walletGradient,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      alignment: Alignment.center,
                      child: _processing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Continue with QPay',
                              style: AppTypography.button.copyWith(color: Colors.white, fontSize: 12),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: AppTypography.caption.copyWith(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
