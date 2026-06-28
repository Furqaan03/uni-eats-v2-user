import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/user_model.dart';
import '../../../models/wallet_transaction_model.dart';
import '../../../services/firestore_order_service.dart';
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
  return ref.read(walletBalanceProvider.notifier).transactions;
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
  StreamSubscription<List<Map<String, dynamic>>>? _incomingTransfersSub;
  final Set<String> _claimingTransferIds = {}; // in-flight claims — never double-claim
  // Owned here instead of a global mutable list on MockDataService — that
  // static was never cleared/scoped per user beyond what this class already
  // does to it, so keeping the real list as this notifier's own state is
  // clearer about where wallet truth actually lives.
  final List<WalletTransactionModel> _transactions = [];
  List<WalletTransactionModel> get transactions => List.unmodifiable(_transactions);

  // Tied to the real authProvider-derived id (kept in sync by the listener
  // above), not MockDataService.currentUser — that static is never cleared
  // on sign-out, so reading it here would keep loading the previous
  // logged-out user's wallet after a fresh logout.
  String get _userId => _lastUserId ?? '';

  void _resetForNewUser() {
    _holds.clear();
    _resolvedOrders.clear();
    _syncHeldTotal();
    state = 0;
    _transactions.clear();
    _incomingTransfersSub?.cancel();
    _incomingTransfersSub = null;
    _claimingTransferIds.clear();
    if (_userId.isNotEmpty) {
      _loadPersisted();
      _listenForIncomingTransfers();
    }
  }

  /// Watches for wallet transfers sent *to* this user and credits them as
  /// soon as they arrive — the sender's client only ever debits itself and
  /// opens a pending walletTransfers doc (rules forbid writing another
  /// user's wallet directly), so the recipient's own client has to be the
  /// one to actually claim the funds into their wallet.
  void _listenForIncomingTransfers() {
    if (!kUseFirebase) return;
    final userId = _userId;
    _incomingTransfersSub = FirestoreOrderService.instance
        .streamIncomingPendingTransfers(userId)
        .listen((pending) {
      for (final transfer in pending) {
        _claimTransfer(userId, transfer);
      }
    }, onError: (Object e) => debugPrint('[Firestore] streamIncomingTransfers failed: $e'));
  }

  Future<void> _claimTransfer(String userId, Map<String, dynamic> transfer) async {
    final transferId = transfer['id'] as String;
    if (!_claimingTransferIds.add(transferId)) return; // already in flight
    final amount = (transfer['amount'] as num).toDouble();
    final fromUserId = transfer['fromUserId'] as String?;
    try {
      final newBalance = state + amount;
      final tx = WalletTransactionModel(
        id: const Uuid().v4(),
        userId: userId,
        amount: amount,
        type: TransactionType.transferIn,
        reference: 'TRF-$transferId',
        description: fromUserId != null ? 'Transfer received' : 'Transfer received',
        timestamp: DateTime.now(),
      );
      await FirestoreOrderService.instance.claimIncomingTransfer(
        transferId: transferId,
        toUserId: userId,
        newRecipientBalance: newBalance,
        recipientTx: tx,
      );
      if (_userId != userId) return; // user switched mid-claim
      state = newBalance;
      _transactions.insert(0, tx);
    } catch (e) {
      debugPrint('[Firestore] claimIncomingTransfer failed: $e');
      _claimingTransferIds.remove(transferId); // allow retry on next snapshot
    }
  }

  Future<void> _loadPersisted() async {
    if (!kUseFirebase) return;
    try {
      final balance = await FirestoreOrderService.instance.fetchWalletBalance(_userId);
      final txs = await FirestoreOrderService.instance.fetchWalletTransactions(_userId);
      if (balance == null) {
        // First run for this user — start a clean wallet at zero, no mock history.
        _transactions.clear();
        await FirestoreOrderService.instance.setWalletBalance(_userId, 0);
        return;
      }
      state = balance;
      if (txs.isNotEmpty) {
        _transactions
          ..clear()
          ..addAll(txs);
      }
    } catch (e) {
      debugPrint('[Firestore] loadPersistedWallet failed: $e');
    }
  }

  /// Applies a balance change and its transaction record together, both
  /// locally and (atomically, via a single Firestore batch) remotely — see
  /// updateWalletBalanceWithTransaction. Keeps top-up/transfer immune to the
  /// same force-close-mid-write class of bug that hit order captures.
  void _applyBalanceChange(double newBalance, WalletTransactionModel tx) {
    state = newBalance;
    _transactions.insert(0, tx);
    if (!kUseFirebase) return;
    FirestoreOrderService.instance
        .updateWalletBalanceWithTransaction(userId: _userId, newBalance: newBalance, tx: tx)
        .catchError((e) => debugPrint('[Firestore] updateWalletBalance failed: $e'));
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

  /// Shrinks (or grows) an existing hold to match an order's new total —
  /// e.g. switching a stuck delivery order to pickup drops the delivery fee
  /// from the total, but the hold map previously kept the original, larger
  /// amount until the order's eventual capture/release, understating
  /// availableBalanceProvider by the difference for as long as it sat
  /// pending. No-op if this order has no active hold (already resolved).
  void adjustHold(String orderId, double newAmount) {
    if (!_holds.containsKey(orderId)) return;
    _holds[orderId] = newAmount;
    _syncHeldTotal();
  }

  /// Re-registers a hold for an order that's still pending from a previous
  /// app session — called when restoring orders on startup.
  void restoreHold(String orderId, double amount) {
    if (_resolvedOrders.contains(orderId) || _holds.containsKey(orderId)) return;
    _holds[orderId] = amount;
    _syncHeldTotal();
  }

  /// Vendor accepted the order — actually deduct the held funds.
  ///
  /// The balance debit, the wallet transaction record, and the order's
  /// paymentStatus flip to 'captured' are written as a single atomic
  /// Firestore batch (see captureOrderPayment) — not three independent
  /// fire-and-forget writes. That used to be the actual cause of the wallet
  /// going negative on a force-close: if the app died between the balance
  /// write and the order's paymentStatus write, the order still read as
  /// 'held' on next launch and got captured a second time. With one atomic
  /// batch, either all of it lands or none of it does, so a retry is safe.
  void capturePayment(String orderId, double amount, {required String description}) {
    if (_resolvedOrders.contains(orderId)) return; // idempotent within this session
    // Defense in depth against a same-session double-call before the batch
    // above even existed in a previous app version — the real guarantee now
    // comes from order.paymentStatus, checked by the caller in orders_provider.
    final alreadyCaptured = _transactions
        .any((tx) => tx.type == TransactionType.payment && tx.reference == 'ORD-$orderId');
    _resolvedOrders.add(orderId);
    if (alreadyCaptured) return;
    _holds.remove(orderId);
    _syncHeldTotal();
    final newBalance = state - amount;
    final tx = WalletTransactionModel(
      id: const Uuid().v4(),
      userId: _userId,
      amount: amount,
      type: TransactionType.payment,
      reference: 'ORD-$orderId',
      description: description,
      timestamp: DateTime.now(),
    );
    state = newBalance;
    _transactions.insert(0, tx);
    if (!kUseFirebase) return;
    FirestoreOrderService.instance
        .captureOrderPayment(orderId: orderId, userId: _userId, newBalance: newBalance, tx: tx)
        .catchError((e) => debugPrint('[Firestore] captureOrderPayment failed: $e'));
  }

  /// Order was rejected/cancelled before acceptance — release the hold, no deduction.
  void releaseHold(String orderId) {
    if (_resolvedOrders.contains(orderId)) return;
    _resolvedOrders.add(orderId);
    if (_holds.remove(orderId) != null) _syncHeldTotal();
  }

  /// Sends [amount] out of the user's wallet to [recipient] (email or
  /// student ID). Returns null on success, an error message on failure.
  ///
  /// Resolves [recipient] to a real account via userDirectory first — the
  /// old version only checked the *shape* of the input (contains '@' or
  /// length >= 6) and debited the sender with no recipient credit at all,
  /// so every transfer just destroyed money. Funds now move via a pending
  /// walletTransfers doc the recipient's own client claims (see
  /// _listenForIncomingTransfers) — this client can't write the recipient's
  /// wallet directly (rules restrict wallets/{uid} writes to its own owner).
  Future<String?> transfer(double amount, {required String recipient}) async {
    if (amount <= 0) return 'Enter a valid amount.';
    if (!canPay(amount)) return 'Insufficient wallet balance.';

    if (!kUseFirebase) return 'Transfers require an active connection.';

    String? toUserId;
    try {
      toUserId = await FirestoreOrderService.instance.lookupUserIdByDirectoryKey(recipient);
    } catch (e) {
      debugPrint('[Firestore] lookupUserIdByDirectoryKey failed: $e');
      return 'Could not verify that recipient. Please try again.';
    }
    if (toUserId == null) return 'No account found for "$recipient".';
    if (toUserId == _userId) return 'You can\'t transfer to yourself.';

    final newBalance = state - amount;
    final transferId = const Uuid().v4();
    final tx = WalletTransactionModel(
      id: const Uuid().v4(),
      userId: _userId,
      amount: amount,
      type: TransactionType.transferOut,
      reference: 'TRF-$transferId',
      description: 'Transfer to $recipient',
      timestamp: DateTime.now(),
    );

    try {
      await FirestoreOrderService.instance.createOutgoingTransfer(
        transferId: transferId,
        fromUserId: _userId,
        toUserId: toUserId,
        amount: amount,
        newSenderBalance: newBalance,
        senderTx: tx,
      );
    } catch (e) {
      debugPrint('[Firestore] createOutgoingTransfer failed: $e');
      return 'Transfer failed. Please try again.';
    }

    state = newBalance;
    _transactions.insert(0, tx);
    return null;
  }

  void topUp(double amount) {
    _applyBalanceChange(
      state + amount,
      WalletTransactionModel(
        id: const Uuid().v4(),
        userId: _userId,
        amount: amount,
        type: TransactionType.topUp,
        reference: 'NOQ-${const Uuid().v4().substring(0, 8).toUpperCase()}',
        description: 'Top-up via Noqoody',
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _incomingTransfersSub?.cancel();
    super.dispose();
  }
}
