import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  /// 0 = Home, 1 = Add Item (FAB placeholder), 2 = Your Items
  final int currentIndex;
  const AppBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: AppColors.surface,
      elevation: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(context, Icons.home_outlined, 'Home', 0, '/home'),
          const SizedBox(width: 48), // space for FAB
          _navItem(
              context, Icons.work_outline, 'Your Items', 2, '/producer/items'),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext ctx, IconData icon, String label, int index,
      String route) {
    final active = index == currentIndex;
    return InkWell(
      onTap: () => Navigator.pushReplacementNamed(ctx, route),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: active ? AppColors.dark : AppColors.textMuted),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    active ? FontWeight.bold : FontWeight.normal,
                color: active ? AppColors.dark : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
