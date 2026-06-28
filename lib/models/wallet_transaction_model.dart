import 'package:flutter/foundation.dart';

enum TransactionType { topUp, payment, refund, transferOut, transferIn }

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

  bool get isCredit =>
      type == TransactionType.topUp || type == TransactionType.refund || type == TransactionType.transferIn;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'amount': amount,
        'type': type.name,
        'reference': reference,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
      };

  factory WalletTransactionModel.fromMap(Map<String, dynamic> map) {
    return WalletTransactionModel(
      id: map['id'] as String,
      userId: map['userId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      type: TransactionType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => TransactionType.payment,
      ),
      reference: map['reference'] as String?,
      description: map['description'] as String?,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
