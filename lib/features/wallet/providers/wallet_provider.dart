import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/wallet_transaction_model.dart';
import '../../../services/mock_data_service.dart';

final walletBalanceProvider = StateNotifierProvider<WalletNotifier, double>((ref) {
  return WalletNotifier();
});

final walletTransactionsProvider = Provider<List<WalletTransactionModel>>((ref) {
  return MockDataService.walletTransactions;
});

class WalletNotifier extends StateNotifier<double> {
  WalletNotifier() : super(MockDataService.currentUser.walletBalance);

  bool canPay(double amount) => state >= amount;

  bool pay(double amount, {required String orderId, required String description}) {
    if (!canPay(amount)) return false;
    state -= amount;
    MockDataService.walletTransactions.insert(
      0,
      WalletTransactionModel(
        id: const Uuid().v4(),
        userId: MockDataService.currentUser.id,
        amount: amount,
        type: TransactionType.payment,
        reference: 'ORD-$orderId',
        description: description,
        timestamp: DateTime.now(),
      ),
    );
    return true;
  }

  void topUp(double amount) {
    state += amount;
    MockDataService.walletTransactions.insert(
      0,
      WalletTransactionModel(
        id: const Uuid().v4(),
        userId: MockDataService.currentUser.id,
        amount: amount,
        type: TransactionType.topUp,
        reference: 'NOQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        description: 'Top-up via Noqoody',
        timestamp: DateTime.now(),
      ),
    );
  }
}
