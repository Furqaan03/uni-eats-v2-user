import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/typography.dart';
import '../../../utils/currency_formatter.dart';

class WalletMiniCard extends StatelessWidget {
  final double balance;

  const WalletMiniCard({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/wallet'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00C853), Color(0xFF007A33)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF007A33).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UNI EATS WALLET',
                      style: AppTypography.label.copyWith(
                        color: Colors.white60,
                        fontSize: 10,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.compact(balance),
                      style: AppTypography.displayMedium.copyWith(
                        color: Colors.white,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '●●●● 4821 · Valid 12/27',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/wallet'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+ TOP UP',
                          style: AppTypography.label.copyWith(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Icon(Icons.chevron_right, color: Colors.white54, size: 22),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
