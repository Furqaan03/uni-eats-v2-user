# Uni Eats v2 — Security TODOs

This file tracks deliberate security deferrals and hardening work that must be completed before production release. The legacy app (`App/app_customer-main/`) contained ~40 vulnerabilities per `RED_TEAM_REPORT.md`; this rebuild addresses architecture-level risks but leaves some integration points as TODOs for the MVP phase.

## Deferred to Post-MVP

1. **Firebase initialization & security rules**
   - `main.dart` currently does not initialize Firebase.
   - Before release: initialize `firebase_core`, configure Firestore/Storage/Auth security rules, and validate them with the Firebase emulator suite.

2. **Payment processing**
   - Wallet top-up in `features/wallet/wallet_screen.dart` is a simulated local flow.
   - Before release: integrate the real Noqoody SDK/server-side flow. **Never** process payments or secrets in the client. Move payment verification to a Cloud Function that updates the wallet balance after server-side confirmation.

3. **Server-side order validation**
   - `features/cart/checkout_screen.dart` computes totals and deducts wallet balance client-side.
   - Before release: order creation and pricing must be validated by a backend/Cloud Function to prevent tampering with amounts, discounts, or delivery fees.

4. **Authentication & authorization**
   - Login screens are not yet implemented; mock user data is used.
   - Before release: implement Firebase Auth with email/institutional SSO and role-based access control (student/faculty only).

5. **Input validation**
   - Search fields, notes, and addresses accept free-form text without strict validation/sanitization.
   - Before release: add server-side input validation, rate limiting, and sanitization for all user inputs.

6. **PII & logging**
   - Crash reporting and analytics are not configured.
   - Before release: configure error reporting (e.g., Crashlytics) with PII redaction. Do not log tokens, passwords, location traces, or wallet details.

7. **Driver location privacy**
   - Live driver tracking uses mock animated coordinates.
   - Before release: stream real locations over an authorized, encrypted channel and expire location history aggressively.

8. **Secrets management**
   - No API keys or secrets are hardcoded yet, but Firebase/Noqoody keys will eventually be required.
   - Store secrets in `.env` / Doppler / native config and keep them out of source control. Verify `.gitignore` excludes `.env` files.

## Completed

- Rebuilt app from scratch instead of refactoring the vulnerable legacy codebase.
- Removed unsafe dynamic typing in the home-screen filter logic.
- Replaced direct mock-data mutations with provider notifiers (`ordersProvider`, `walletBalanceProvider`).
