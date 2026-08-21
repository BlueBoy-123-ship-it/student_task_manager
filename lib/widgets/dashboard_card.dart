import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const DashboardCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 12,
        ),
        child: Column(
          children: [
            // =================================================
            // ICON
            // =================================================

            CircleAvatar(
              radius: 22,
              backgroundColor:
                  color.withValues(alpha: 0.15),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),

            const SizedBox(height: 12),

            // =================================================
            // VALUE
            // =================================================

            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 4),

            // =================================================
            // TITLE
            // =================================================

            Text(
              title,
              style: TextStyle(
                color:
                    colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}