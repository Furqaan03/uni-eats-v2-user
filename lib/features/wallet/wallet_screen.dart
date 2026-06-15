import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../models/wallet_transaction_model.dart';
import '../../services/mock_data_service.dart';
import '../../utils/currency_formatter.dart';
import 'providers/wallet_provider.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final balance = ref.watch(walletBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Wallet',
          style: AppTypography.heading.copyWith(color: textPrimary),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _BalanceCard(balance: balance),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: AppTypography.subheading.copyWith(color: textPrimary),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'See All',
                    style: AppTypography.caption.copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: MockDataService.walletTransactions.length,
              itemBuilder: (context, index) {
                final tx = MockDataService.walletTransactions[index];
                return _TransactionTile(tx: tx, textSecondary: textSecondary);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showTopUpSheet(context, ref),
                child: const Text('Top Up with Noqoody'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTopUpSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopUpSheet(
        onTopUp: (amount) {
          ref.read(walletBalanceProvider.notifier).topUp(amount);
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;

  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Balance',
            style: AppTypography.body.copyWith(color: Colors.white.withOpacity(0.9)),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(balance),
            style: AppTypography.balance.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Secured by Noqoody',
                style: AppTypography.caption.copyWith(color: Colors.white.withOpacity(0.9)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransactionModel tx;
  final Color textSecondary;

  const _TransactionTile({required this.tx, required this.textSecondary});

  @override
  Widget build(BuildContext context) {
    final isDebit = !tx.isCredit;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDebit ? AppColors.danger.withOpacity(0.10) : AppColors.primary.withOpacity(0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isDebit ? Icons.shopping_bag_outlined : Icons.account_balance_wallet_outlined,
          color: isDebit ? AppColors.danger : AppColors.primary,
        ),
      ),
      title: Text(
        tx.description ?? (tx.isCredit ? 'Top up' : 'Payment'),
        style: AppTypography.body.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        tx.timestamp.toLocal().toString().split(' ').first,
        style: AppTypography.caption.copyWith(color: textSecondary),
      ),
      trailing: Text(
        '${isDebit ? '-' : '+'}${CurrencyFormatter.format(tx.amount)}',
        style: AppTypography.subheading.copyWith(
          color: isDebit ? AppColors.danger : AppColors.primary,
        ),
      ),
    );
  }
}

class _TopUpSheet extends StatefulWidget {
  final ValueChanged<double> onTopUp;

  const _TopUpSheet({required this.onTopUp});

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  double _selectedAmount = 50;
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface3 : AppColors.lightSurface2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Top Up Wallet',
            style: AppTypography.subheading.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select an amount to add via Noqoody.',
            style: AppTypography.caption.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [20.0, 50.0, 100.0, 200.0].map((amount) {
              final selected = _selectedAmount == amount;
              return ChoiceChip(
                label: Text(CurrencyFormatter.format(amount)),
                selected: selected,
                onSelected: (_) => setState(() => _selectedAmount = amount),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _processing
                  ? null
                  : () async {
                      setState(() => _processing = true);
                      await Future.delayed(const Duration(seconds: 1));
                      if (!mounted) return;
                      widget.onTopUp(_selectedAmount);
                      Navigator.pop(context);
                    },
              child: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Pay ${CurrencyFormatter.format(_selectedAmount)}'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            // TODO: Replace with real Noqoody SDK integration.
            'This is a simulated top-up. Replace with Noqoody payment flow before release.',
            style: AppTypography.caption.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
