import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kLocationEmojiOptions = ['🏠', '🏢', '📚', '💼', '🏋️', '🎓', '📍', '🍕', '☕', '🅿️'];

/// A saved drop-off location. [mapX]/[mapY] are 0..1 fractions of the campus
/// map (see CampusMapPainter) for the pinned spot — null if the user typed an
/// address without dropping a pin.
@immutable
class SavedLocation {
  final String emoji;
  final String label;
  final String address;
  final double? mapX;
  final double? mapY;

  const SavedLocation({
    required this.emoji,
    required this.label,
    required this.address,
    this.mapX,
    this.mapY,
  });

  SavedLocation copyWith({
    String? emoji,
    String? label,
    String? address,
    double? mapX,
    double? mapY,
  }) {
    return SavedLocation(
      emoji: emoji ?? this.emoji,
      label: label ?? this.label,
      address: address ?? this.address,
      mapX: mapX ?? this.mapX,
      mapY: mapY ?? this.mapY,
    );
  }

  Map<String, dynamic> toJson() => {
        'emoji': emoji,
        'label': label,
        'address': address,
        'mapX': mapX,
        'mapY': mapY,
      };

  factory SavedLocation.fromJson(Map<String, dynamic> json) => SavedLocation(
        emoji: json['emoji'] as String? ?? '📍',
        label: json['label'] as String? ?? '',
        address: json['address'] as String? ?? '',
        mapX: (json['mapX'] as num?)?.toDouble(),
        mapY: (json['mapY'] as num?)?.toDouble(),
      );
}

/// Persisted (SharedPreferences-backed) list of the user's saved drop-off
/// locations. Previously this list lived in a sheet widget's local State,
/// so every "+ Add Location" was lost the moment the sheet closed.
final savedLocationsProvider =
    StateNotifierProvider<SavedLocationsNotifier, List<SavedLocation>>((ref) {
  return SavedLocationsNotifier();
});

class SavedLocationsNotifier extends StateNotifier<List<SavedLocation>> {
  SavedLocationsNotifier() : super(_defaults) {
    _load();
  }

  static const _key = 'saved_locations_v1';

  static const _defaults = [
    SavedLocation(emoji: '🏠', label: 'Home', address: 'Building B3, Room 204'),
    SavedLocation(emoji: '📚', label: 'Library', address: 'UDST Main Library, 2nd Floor'),
  ];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => SavedLocation.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } catch (e) {
      debugPrint('[Preferences] failed to load saved locations: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  Future<void> add(SavedLocation location) async {
    state = [...state, location];
    await _persist();
  }

  Future<void> updateAt(int index, SavedLocation location) async {
    state = [
      for (var i = 0; i < state.length; i++) if (i == index) location else state[i],
    ];
    await _persist();
  }

  Future<void> removeAt(int index) async {
    state = [
      for (var i = 0; i < state.length; i++) if (i != index) state[i],
    ];
    await _persist();
  }
}

/// Persisted default drop-off selection — previously reset to a hardcoded
/// 'B3' every time the picker sheet opened, so the choice never actually stuck.
@immutable
class DropoffOption {
  final String code;
  final String name;

  const DropoffOption(this.code, this.name);
}

const kDropoffOptions = [
  DropoffOption('B1', 'Building 1 – Main Lobby'),
  DropoffOption('B2', 'Building 2 – Library Entrance'),
  DropoffOption('B3', 'Building 3 – Room 204'),
  DropoffOption('B4', 'Building 4 – Cafeteria'),
  DropoffOption('B5', 'Building 5 – Lab Wing'),
  DropoffOption('Student Centre', 'Ground Floor, Reception'),
];

final defaultDropoffProvider =
    StateNotifierProvider<DefaultDropoffNotifier, DropoffOption>((ref) {
  return DefaultDropoffNotifier();
});

class DefaultDropoffNotifier extends StateNotifier<DropoffOption> {
  DefaultDropoffNotifier() : super(kDropoffOptions[2]) {
    _load();
  }

  static const _key = 'default_dropoff_code_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code == null) return;
    final match = kDropoffOptions.where((o) => o.code == code);
    if (match.isNotEmpty) state = match.first;
  }

  Future<void> setOption(DropoffOption option) async {
    state = option;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, option.code);
  }
}

/// Persisted set of favourited restaurant ids.
final favoriteRestaurantIdsProvider =
    StateNotifierProvider<FavoriteRestaurantIdsNotifier, Set<String>>((ref) {
  return FavoriteRestaurantIdsNotifier();
});

class FavoriteRestaurantIdsNotifier extends StateNotifier<Set<String>> {
  FavoriteRestaurantIdsNotifier() : super(const {}) {
    _load();
  }

  static const _key = 'favorite_restaurant_ids_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key);
    if (list != null) state = list.toSet();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.toList());
  }

  Future<void> toggle(String restaurantId) async {
    final next = {...state};
    if (next.contains(restaurantId)) {
      next.remove(restaurantId);
    } else {
      next.add(restaurantId);
    }
    state = next;
    await _persist();
  }
}

/// Persisted notification preferences — previously these were plain widget
/// State fields reset to (true, true, true, false) on every cold start, so
/// the "X active" count and the toggles themselves never actually stuck
/// across a force-close.
@immutable
class NotificationPrefs {
  final bool orderUpdates;
  final bool promotions;
  final bool driverNearby;
  final bool loyaltyRewards;

  const NotificationPrefs({
    this.orderUpdates = true,
    this.promotions = true,
    this.driverNearby = true,
    this.loyaltyRewards = false,
  });

  int get activeCount =>
      [orderUpdates, promotions, driverNearby, loyaltyRewards].where((v) => v).length;

  NotificationPrefs copyWith({
    bool? orderUpdates,
    bool? promotions,
    bool? driverNearby,
    bool? loyaltyRewards,
  }) {
    return NotificationPrefs(
      orderUpdates: orderUpdates ?? this.orderUpdates,
      promotions: promotions ?? this.promotions,
      driverNearby: driverNearby ?? this.driverNearby,
      loyaltyRewards: loyaltyRewards ?? this.loyaltyRewards,
    );
  }

  Map<String, dynamic> toJson() => {
        'orderUpdates': orderUpdates,
        'promotions': promotions,
        'driverNearby': driverNearby,
        'loyaltyRewards': loyaltyRewards,
      };

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) => NotificationPrefs(
        orderUpdates: json['orderUpdates'] as bool? ?? true,
        promotions: json['promotions'] as bool? ?? true,
        driverNearby: json['driverNearby'] as bool? ?? true,
        loyaltyRewards: json['loyaltyRewards'] as bool? ?? false,
      );
}

final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, NotificationPrefs>((ref) {
  return NotificationPrefsNotifier();
});

class NotificationPrefsNotifier extends StateNotifier<NotificationPrefs> {
  NotificationPrefsNotifier() : super(const NotificationPrefs()) {
    _load();
  }

  static const _key = 'notification_prefs_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      state = NotificationPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[Preferences] failed to load notification prefs: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> update(NotificationPrefs Function(NotificationPrefs) updater) async {
    state = updater(state);
    await _persist();
  }
}
