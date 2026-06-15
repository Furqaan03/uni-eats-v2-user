import 'package:flutter/foundation.dart';

enum UserRole { student, faculty, staff }

@immutable
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String universityId;
  final UserRole role;
  final double walletBalance;
  final int loyaltyPoints;
  final List<String> dietaryPreferences;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.universityId,
    required this.role,
    this.walletBalance = 0.0,
    this.loyaltyPoints = 0,
    this.dietaryPreferences = const [],
    this.avatarUrl,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? universityId,
    UserRole? role,
    double? walletBalance,
    int? loyaltyPoints,
    List<String>? dietaryPreferences,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      universityId: universityId ?? this.universityId,
      role: role ?? this.role,
      walletBalance: walletBalance ?? this.walletBalance,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  String get roleLabel {
    return switch (role) {
      UserRole.student => 'Student',
      UserRole.faculty => 'Faculty',
      UserRole.staff => 'Staff',
    };
  }
}
