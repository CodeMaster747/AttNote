// screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import '../models/attendance_model.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/widgets.dart';
import '../services/analytics_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  AttendanceAnalytics? _analytics;
  bool _isLoading = false;
  String _viewMode = 'weekly'; // 'weekly' or 'monthly'

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      DateTime startDate;

      if (_viewMode == 'weekly') {
        startDate = now.subtract(const Duration(days: 7));
      } else {
        startDate = now.subtract(const Duration(days: 30));
      }

      final analytics = await _analyticsService.getAttendanceAnalytics(
        uid,
        startDate: startDate,
        endDate: now,
      );

      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading analytics: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Analytics'),
        actions: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'weekly', label: Text('Week')),
              ButtonSegment(value: 'monthly', label: Text('Month')),
            ],
            selected: {_viewMode},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _viewMode = newSelection.first;
              });
              _loadAnalytics();
            },
          ),
          const Gap(AppSpacing.md),
        ],
      ),
      body: _isLoading
          ? const ShimmerCardList(itemCount: 4)
          : _analytics == null
          ? const EmptyState(
              title: 'No analytics data available',
              message: 'Track attendance to see insights here.',
              icon: Icons.analytics_outlined,
            )
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: AppSpacing.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overall Stats Card
                    _buildOverallStatsCard(),

                    const Gap(AppSpacing.lg),

                    // Attendance Over Time (Line Chart)
                    const SectionHeader(
                      title: 'Attendance Trend',
                      padding: EdgeInsets.zero,
                    ),
                    const Gap(AppSpacing.sm),
                    _buildAttendanceTrendChart(),

                    const Gap(AppSpacing.lg),

                    // Subject-wise Comparison (Bar Chart)
                    const SectionHeader(
                      title: 'Subject-wise Comparison',
                      padding: EdgeInsets.zero,
                    ),
                    const Gap(AppSpacing.sm),
                    _buildSubjectComparisonChart(),

                    const Gap(AppSpacing.lg),

                    // Distribution (Pie Chart)
                    const SectionHeader(
                      title: 'Attendance Distribution',
                      padding: EdgeInsets.zero,
                    ),
                    const Gap(AppSpacing.sm),
                    _buildDistributionChart(),
                    const Gap(AppSpacing.lg),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverallStatsCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall Statistics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Gap(AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total',
                  _analytics!.totalClasses.toString(),
                  colorScheme.primary,
                ),
                _buildStatItem(
                  'Present',
                  _analytics!.totalPresent.toString(),
                  colorScheme.tertiary,
                ),
                _buildStatItem(
                  'Absent',
                  _analytics!.totalAbsent.toString(),
                  colorScheme.error,
                ),
                _buildStatItem(
                  'Percentage',
                  '${_analytics!.overallPercentage.toStringAsFixed(1)}%',
                  colorScheme.secondary,
                ),
              ],
            ),
          ],
        ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const Gap(AppSpacing.xxs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildAttendanceTrendChart() {
    if (_analytics!.attendanceOverTime.isEmpty) {
      return const EmptyState(
        title: 'No trend data available',
        message: 'Try switching between weekly and monthly views.',
        icon: Icons.show_chart_rounded,
      );
    }

    final sortedEntries = _analytics!.attendanceOverTime.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final colorScheme = Theme.of(context).colorScheme;
    final lineColor = colorScheme.primary;

    return AppCard(
      child: SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 20,
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: Theme.of(context).textTheme.labelSmall,
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= sortedEntries.length) {
                        return const Text('');
                      }
                      final date = sortedEntries[value.toInt()].key;
                      return Text(
                        '${date.day}/${date.month}',
                        style: Theme.of(context).textTheme.labelSmall,
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              minY: 0,
              maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: sortedEntries
                      .asMap()
                      .entries
                      .map(
                        (entry) =>
                            FlSpot(entry.key.toDouble(), entry.value.value),
                      )
                      .toList(),
                  isCurved: true,
                  color: lineColor,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: lineColor.withValues(alpha: 0.18),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildSubjectComparisonChart() {
    if (_analytics!.subjectWiseStats.isEmpty) {
      return const EmptyState(
        title: 'No subject data available',
        message: 'Subject comparison appears once attendance is recorded.',
        icon: Icons.bar_chart_rounded,
      );
    }

    return AppCard(
      child: SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: Theme.of(context).textTheme.labelSmall,
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (value, meta) {
                      final subjects = _analytics!.subjectWiseStats.keys
                          .toList();
                      if (value.toInt() >= subjects.length) {
                        return const Text('');
                      }
                      final subject = subjects[value.toInt()];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          subject.length > 10
                              ? '${subject.substring(0, 10)}...'
                              : subject,
                          style: Theme.of(context).textTheme.labelSmall,
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              barGroups: _analytics!.subjectWiseStats.entries
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) {
                    final index = entry.key;
                    final stats = entry.value.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: stats.attendancePercentage,
                          color: _getBarColor(stats.attendancePercentage),
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  })
                  .toList(),
            ),
          ),
        ),
    );
  }

  Color _getBarColor(double percentage) {
    final colorScheme = Theme.of(context).colorScheme;
    if (percentage >= 75) return colorScheme.tertiary;
    if (percentage >= 50) return colorScheme.secondary;
    return colorScheme.error;
  }

  Widget _buildDistributionChart() {
    final colorScheme = Theme.of(context).colorScheme;

    final total = _analytics!.totalClasses;
    if (total == 0) {
      return const EmptyState(
        title: 'No attendance data',
        message: 'Distribution will appear once classes are recorded.',
        icon: Icons.pie_chart_rounded,
      );
    }

    return AppCard(
      child: SizedBox(
          height: 250,
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 60,
                    sections: [
                      PieChartSectionData(
                        value: _analytics!.totalPresent.toDouble(),
                        title:
                            '${((_analytics!.totalPresent / total) * 100).toStringAsFixed(1)}%',
                        color: colorScheme.tertiary,
                        radius: 80,
                        titleStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onTertiary,
                        ),
                      ),
                      PieChartSectionData(
                        value: _analytics!.totalAbsent.toDouble(),
                        title:
                            '${((_analytics!.totalAbsent / total) * 100).toStringAsFixed(1)}%',
                        color: colorScheme.error,
                        radius: 80,
                        titleStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onError,
                        ),
                      ),
                      if (_analytics!.totalCancelled > 0)
                        PieChartSectionData(
                          value: _analytics!.totalCancelled.toDouble(),
                          title:
                              '${((_analytics!.totalCancelled / total) * 100).toStringAsFixed(1)}%',
                          color: colorScheme.secondary,
                          radius: 80,
                          titleStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Gap(AppSpacing.md),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem(
                    'Present',
                    colorScheme.tertiary,
                    _analytics!.totalPresent,
                  ),
                  const Gap(AppSpacing.xs),
                  _buildLegendItem(
                    'Absent',
                    colorScheme.error,
                    _analytics!.totalAbsent,
                  ),
                  if (_analytics!.totalCancelled > 0) ...[
                    const Gap(AppSpacing.xs),
                    _buildLegendItem(
                      'Cancelled',
                      colorScheme.secondary,
                      _analytics!.totalCancelled,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const Gap(AppSpacing.xs),
        Text('$label: $count'),
      ],
    );
  }
}
