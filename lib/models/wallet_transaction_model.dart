import 'package:flutter/foundation.dart';

enum TransactionType { topUp, payment, refund }

@immutable
class WalletTransactionModel {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type;
  final String? reference;
  final String? description;
  final DateTime timestamp;

  const WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    this.reference,
    this.description,
    required this.timestamp,
  });

  WalletTransactionModel copyWith({
    String? id,
    String? userId,
    double? amount,
    TransactionType? type,
    String? reference,
    String? description,
    DateTime? timestamp,
  }) {
    return WalletTransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      reference: reference ?? this.reference,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  bool get isCredit => type == TransactionType.topUp || type == TransactionType.refund;
}
