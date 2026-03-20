import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/app_models.dart';
import 'premium_surfaces.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 52, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Hero(
          tag: 'brand-mark',
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.32),
              color: AppColors.riderPrimary,
            ),
            child: Padding(
              padding: EdgeInsets.all(size * 0.2),
              child: SvgPicture.asset(
                'assets/icons/brand_mark.svg',
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Rider app', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ],
    );
  }
}

class PremiumBottomNavItem {
  const PremiumBottomNavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class PremiumBottomNavigation extends StatelessWidget {
  const PremiumBottomNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<PremiumBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final entry in items.indexed)
              Expanded(
                child: _PremiumBottomNavButton(
                  item: entry.$2,
                  isSelected: entry.$1 == currentIndex,
                  onTap: () => onTap(entry.$1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PremiumBottomNavButton extends StatelessWidget {
  const _PremiumBottomNavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final PremiumBottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 60,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isSelected ? scheme.primaryContainer : Colors.transparent,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RoutePainter(
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.lg,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Row(
                children: [
                  const StatusPill(
                    label: 'Live route preview',
                    color: AppColors.sky,
                    icon: Icons.navigation_rounded,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.layers_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const Positioned(
              left: 36,
              top: 92,
              child: _MapPin(label: 'Pickup', color: AppColors.ember),
            ),
            const Positioned(
              right: 42,
              bottom: 84,
              child: _MapPin(label: 'Drop', color: AppColors.emerald),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.currentStage});

  final DeliveryStage currentStage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final stage in DeliveryStage.values.indexed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: stage.$1 <= currentStage.index
                          ? AppColors.riderPrimary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  if (stage.$1 != DeliveryStage.values.length - 1)
                    Container(
                      width: 2,
                      height: 40,
                      color: stage.$1 < currentStage.index
                          ? AppColors.riderPrimary.withValues(alpha: 0.4)
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stageLabel(stage.$2),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _stageDescription(stage.$2),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _stageLabel(DeliveryStage stage) => switch (stage) {
    DeliveryStage.assigned => 'Assigned',
    DeliveryStage.accepted => 'Accepted',
    DeliveryStage.reachedRestaurant => 'Reached restaurant',
    DeliveryStage.pickedUp => 'Picked up',
    DeliveryStage.onTheWay => 'On the way',
    DeliveryStage.reachedCustomer => 'Arrived at customer',
    DeliveryStage.delivered => 'Delivered',
  };

  String _stageDescription(DeliveryStage stage) => switch (stage) {
    DeliveryStage.assigned => 'Dispatch has reserved this order for you.',
    DeliveryStage.accepted => 'Customer and restaurant have been notified.',
    DeliveryStage.reachedRestaurant => 'Confirm arrival and prep handoff.',
    DeliveryStage.pickedUp => 'Items are sealed and ready for drop.',
    DeliveryStage.onTheWay => 'Route is optimized for the next milestone.',
    DeliveryStage.reachedCustomer =>
      'Final handoff checkpoint before completion.',
    DeliveryStage.delivered => 'OTP matched and earnings are secured.',
  };
}

class InsightChart extends StatelessWidget {
  const InsightChart({
    super.key,
    required this.points,
    this.accent = AppColors.riderPrimary,
  });

  final List<EarningsPoint> points;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceBetween,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: points.isEmpty ? 1 : null,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Theme.of(context).colorScheme.outlineVariant,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        points[index].label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(enabled: false),
            barGroups: [
              for (final entry in points.indexed)
                BarChartGroupData(
                  x: entry.$1,
                  barRods: [
                    BarChartRodData(
                      toY: entry.$2.amount,
                      width: 18,
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [accent, accent.withValues(alpha: 0.5)],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const Icon(Icons.place, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final routePaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.sky, AppColors.riderPrimary, AppColors.emerald],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final route = Path()
      ..moveTo(48, 120)
      ..quadraticBezierTo(size.width * 0.44, 36, size.width * 0.55, 130)
      ..quadraticBezierTo(
        size.width * 0.74,
        size.height * 0.42,
        size.width - 52,
        size.height - 92,
      );

    canvas.drawPath(route, roadPaint);
    canvas.drawPath(route, routePaint);

    final dottedPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    for (double x = 18; x < size.width; x += 44) {
      for (double y = 18; y < size.height; y += 44) {
        canvas.drawCircle(Offset(x, y), 1.1, dottedPaint);
      }
    }

    final swirlPaint = Paint()
      ..color = AppColors.riderPrimary.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 3; i++) {
      final path = Path();
      final startX = size.width * (0.16 + i * 0.22);
      path.moveTo(startX, size.height * 0.82);
      for (double t = 0; t < 1; t += 0.02) {
        final dx = startX + t * 120;
        final dy = size.height * (0.84 - math.sin(t * math.pi * 2) * 18);
        path.lineTo(dx, dy);
      }
      canvas.drawPath(path, swirlPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
