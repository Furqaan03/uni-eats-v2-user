import 'package:flutter/foundation.dart';

enum CampusLocationType { restaurant, academic, residential, facility, parking }

@immutable
class CampusLocationModel {
  final String id;
  final String label;
  final String fullName;
  final CampusLocationType type;
  final double x;
  final double y;
  final double width;
  final double height;

  const CampusLocationModel({
    required this.id,
    required this.label,
    required this.fullName,
    required this.type,
    required this.x,
    required this.y,
    this.width = 1.0,
    this.height = 1.0,
  });
}
