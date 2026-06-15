# Uni Eats v2 — Agent Notes

## Project
Flutter campus food delivery app for UDST students and faculty.

## Build & Run
```bash
cd unieats_v2
flutter pub get
flutter run
```

Web build (fastest verification):
```bash
flutter build web
```

iOS/macOS builds require CocoaPods and may hit Swift Package Manager issues when the project path contains spaces; disable SPM with `flutter config --no-enable-swift-package-manager` if needed.

## Architecture
- `lib/core/` — theme, typography, shared widgets.
- `lib/models/` — immutable data models.
- `lib/services/mock_data_service.dart` — all hardcoded mock data.
- `lib/features/` — per-feature screens + Riverpod providers.
- `lib/campus_map/campus_map_painter.dart` — custom `CustomPainter` campus map.
- `lib/router.dart` — `go_router` with `StatefulShellRoute` for bottom nav.
- `lib/shell/dashboard_shell.dart` — hosts `PillNavBar` around tab branches.

## Conventions
- Use Riverpod `StateNotifierProvider` for mutable state (cart, wallet, orders).
- Keep widgets under 250 lines; extract private helper widgets when they grow.
- Brand colors live in `lib/core/theme/colors.dart` (`#02BA26` primary).
- Fonts: `Jumper` (headings/brand), `Satoshi` (UI/body). Both declared in `pubspec.yaml`.

## Known Limitations
- Noqoody integration is mocked; see `SECURITY_TODOS.md`.
- Campus map coordinates are normalized (0–1) and hand-placed from the UDST map image.
- Auth screens and deep backend integration are not implemented yet.

## Security
Read `SECURITY_TODOS.md` before touching checkout, wallet, auth, or Firebase integration.
