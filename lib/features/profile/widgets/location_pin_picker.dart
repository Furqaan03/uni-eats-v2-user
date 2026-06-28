import 'package:flutter/material.dart';

import '../../../campus_map/campus_map_painter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../services/mock_data_service.dart';

/// Tap-to-drop-pin campus map for picking the exact spot a saved location
/// refers to. Coordinates are normalized [0,1] fractions of the map, same
/// scheme CampusMapPainter already uses for restaurant/building pins.
class LocationPinPicker extends StatefulWidget {
  final double? initialX;
  final double? initialY;
  final ValueChanged<Offset> onPinSet;

  const LocationPinPicker({
    super.key,
    this.initialX,
    this.initialY,
    required this.onPinSet,
  });

  @override
  State<LocationPinPicker> createState() => _LocationPinPickerState();
}

class _LocationPinPickerState extends State<LocationPinPicker> {
  Offset? _pin;

  @override
  void initState() {
    super.initState();
    if (widget.initialX != null && widget.initialY != null) {
      _pin = Offset(widget.initialX!, widget.initialY!);
    }
  }

  void _handleTap(TapUpDetails details, Size size) {
    final dx = (details.localPosition.dx / size.width).clamp(0.0, 1.0);
    final dy = (details.localPosition.dy / size.height).clamp(0.0, 1.0);
    final pin = Offset(dx, dy);
    setState(() => _pin = pin);
    widget.onPinSet(pin);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap the map to pin the exact spot',
          style: AppTypography.caption.copyWith(
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, 150);
              return GestureDetector(
                onTapUp: (d) => _handleTap(d, size),
                child: CustomPaint(
                  size: size,
                  painter: CampusMapPainter(
                    locations: MockDataService.campusLocations,
                    destinationPosition: _pin,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
