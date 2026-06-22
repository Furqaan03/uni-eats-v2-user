import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/user_model.dart';
import '../../../models/wallet_transaction_model.dart';
import '../../../services/firestore_order_service.dart';
import '../../../services/mock_data_service.dart';
import '../../auth/providers/auth_provider.dart';

final walletBalanceProvider = StateNotifierProvider<WalletNotifier, double>((ref) {
  return WalletNotifier(ref);
});

/// Total currently held against pending (not-yet-accepted) orders.
final _heldTotalProvider = StateProvider<double>((ref) => 0);

/// Balance minus active holds — what the user can actually spend right now.
/// Use this (not [walletBalanceProvider]) for checkout "can afford" checks.
final availableBalanceProvider = Provider<double>((ref) {
  final balance = ref.watch(walletBalanceProvider);
  final held = ref.watch(_heldTotalProvider);
  return (balance - held).clamp(0, double.infinity);
});

final walletTransactionsProvider = Provider<List<WalletTransactionModel>>((ref) {
  // Re-read on every balance change so the list reflects newly persisted transactions.
  ref.watch(walletBalanceProvider);
  return List.unmodifiable(MockDataService.walletTransactions);
});

class WalletNotifier extends StateNotifier<double> {
  WalletNotifier(this._ref) : super(0) {
    // Reload from scratch whenever the authenticated user changes — covers
    // app start (no user yet -> real user), and logout/login as someone else.
    _ref.listen<UserModel?>(authProvider, (previous, next) {
      final newId = next?.id ?? '';
      if (newId == _lastUserId) return;
      _lastUserId = newId;
      _resetForNewUser();
    }, fireImmediately: true);
  }

  final Ref _ref;
  String? _lastUserId;
  final Map<String, double> _holds = {};
  final Set<String> _resolvedOrders = {}; // captured or released — never act twice

  String get _userId => MockDataService.currentUser.id;

  void _resetForNewUser() {
    _holds.clear();
    _resolvedOrders.clear();
    _syncHeldTotal();
    state = 0;
    MockDataService.walletTransactions.clear();
    if (_userId.isNotEmpty) _loadPersisted();
  }

  Future<void> _loadPersisted() async {
    if (!kUseFirebase) return;
    try {
      final balance = await FirestoreOrderService.instance.fetchWalletBalance(_userId);
      final txs = await FirestoreOrderService.instance.fetchWalletTransactions(_userId);
      if (balance == null) {
        // First run for this user — start a clean wallet at zero, no mock history.
        MockDataService.walletTransactions.clear();
        await FirestoreOrderService.instance.setWalletBalance(_userId, 0);
        return;
      }
      state = balance;
      if (txs.isNotEmpty) {
        MockDataService.walletTransactions
          ..clear()
          ..addAll(txs);
      }
    } catch (e) {
      debugPrint('[Firestore] loadPersistedWallet failed: $e');
    }
  }

  void _persistBalance() {
    if (!kUseFirebase) return;
    FirestoreOrderService.instance
        .setWalletBalance(_userId, state)
        .catchError((e) => debugPrint('[Firestore] persistBalance failed: $e'));
  }

  void _recordTransaction(WalletTransactionModel tx) {
    MockDataService.walletTransactions.insert(0, tx);
    if (!kUseFirebase) return;
    FirestoreOrderService.instance
        .addWalletTransaction(_userId, tx)
        .catchError((e) => debugPrint('[Firestore] persistTransaction failed: $e'));
  }

  void _syncHeldTotal() {
    final total = _holds.values.fold(0.0, (a, b) => a + b);
    _ref.read(_heldTotalProvider.notifier).state = total;
  }

  bool canPay(double amount) => (state - _holds.values.fold(0.0, (a, b) => a + b)) >= amount;

  /// Reserves [amount] against [orderId] at checkout, without deducting it yet.
  /// The hold is released (if rejected) or captured (if accepted) later.
  bool hold(double amount, {required String orderId}) {
    if (!canPay(amount)) return false;
    _holds[orderId] = amount;
    _syncHeldTotal();
    return true;
  }

  /// Re-registers a hold for an order that's still pending from a previous
  /// app session — called when restoring orders on startup.
  void restoreHold(String orderId, double amount) {
    if (_resolvedOrders.contains(orderId) || _holds.containsKey(orderId)) return;
    _holds[orderId] = amount;
    _syncHeldTotal();
  }

  /// Vendor accepted the order — actually deduct the held funds.
  void capturePayment(String orderId, double amount, {required String description}) {
    if (_resolvedOrders.contains(orderId)) return; // idempotent within this session
    // Defense in depth across restarts: if a payment transaction for this
    // order already exists (e.g. the Firestore paymentStatus write from a
    // previous session didn't land before the app closed), don't deduct again.
    final alreadyCaptured = MockDataService.walletTransactions
        .any((tx) => tx.type == TransactionType.payment && tx.reference == 'ORD-$orderId');
    _resolvedOrders.add(orderId);
    if (alreadyCaptured) return;
    _holds.remove(orderId);
    _syncHeldTotal();
    state -= amount;
    _persistBalance();
    _recordTransaction(WalletTransactionModel(
      id: const Uuid().v4(),
      userId: _userId,
      amount: amount,
      type: TransactionType.payment,
      reference: 'ORD-$orderId',
      description: description,
      timestamp: DateTime.now(),
    ));
  }

  /// Order was rejected/cancelled before acceptance — release the hold, no deduction.
  void releaseHold(String orderId) {
    if (_resolvedOrders.contains(orderId)) return;
    _resolvedOrders.add(orderId);
    if (_holds.remove(orderId) != null) _syncHeldTotal();
  }

  /// Sends [amount] out of the user's wallet to [recipient] (email or student ID).
  /// Returns null on success, an error message on failure.
  String? transfer(double amount, {required String recipient}) {
    if (amount <= 0) return 'Enter a valid amount.';
    if (!canPay(amount)) return 'Insufficient wallet balance.';
    state -= amount;
    _persistBalance();
    _recordTransaction(WalletTransactionModel(
      id: const Uuid().v4(),
      userId: _userId,
      amount: amount,
      type: TransactionType.transferOut,
      reference: 'TRF-${const Uuid().v4().substring(0, 8).toUpperCase()}',
      description: 'Transfer to $recipient',
      timestamp: DateTime.now(),
    ));
    return null;
  }

  void topUp(double amount) {
    state += amount;
    _persistBalance();
    _recordTransaction(WalletTransactionModel(
      id: const Uuid().v4(),
      userId: _userId,
      amount: amount,
      type: TransactionType.topUp,
      reference: 'NOQ-${const Uuid().v4().substring(0, 8).toUpperCase()}',
      description: 'Top-up via Noqoody',
      timestamp: DateTime.now(),
    ));
  }
}
