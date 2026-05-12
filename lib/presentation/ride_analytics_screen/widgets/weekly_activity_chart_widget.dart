import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../widgets/app_icons.dart';

class WeeklyActivityChartWidget extends StatefulWidget {
  final List<double> weeklyData;
  final String period;

  const WeeklyActivityChartWidget({
    super.key,
    required this.weeklyData,
    required this.period,
  });

  @override
  State<WeeklyActivityChartWidget> createState() =>
      _WeeklyActivityChartWidgetState();
}

class _WeeklyActivityChartWidgetState extends State<WeeklyActivityChartWidget> {
  int _touchedIndex = -1;

  static const Color _primary = Color(0xFF1B365D);
  static const Color _gold = Color(0xFFFFB347);
  static const Color _orange = Color(0xFFE85A4F);

  List<String> get _labels {
    if (widget.period == 'week') {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    } else if (widget.period == 'month') {
      return ['W1', 'W2', 'W3', 'W4'];
    } else {
      return [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = widget.weeklyData.isEmpty
        ? 5.0
        : (widget.weeklyData.reduce((a, b) => a > b ? a : b) + 1);

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(AppIcons.help, color: _primary, size: 16),
              ),
              SizedBox(width: 2.w),
              Text(
                'Ride Activity',
                style: GoogleFonts.dmSans(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (_touchedIndex >= 0 &&
                  _touchedIndex < widget.weeklyData.length)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 2.w,
                    vertical: 0.4.h,
                  ),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    '${widget.weeklyData[_touchedIndex].toInt()} rides',
                    style: GoogleFonts.dmSans(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: _orange,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 2.h),
          SizedBox(
            height: 18.h,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: _primary.withValues(alpha: 0.9),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toInt()} rides',
                        GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                  touchCallback: (event, response) {
                    setState(() {
                      if (response == null ||
                          response.spot == null ||
                          event is FlTapUpEvent == false) {
                        if (event is FlPointerExitEvent) {
                          _touchedIndex = -1;
                        }
                      } else {
                        _touchedIndex = response.spot!.touchedBarGroupIndex;
                      }
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= _labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _labels[idx],
                            style: GoogleFonts.dmSans(
                              fontSize: 9.sp,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: _touchedIndex == idx
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == maxY) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value.toInt().toString(),
                          style: GoogleFonts.dmSans(
                            fontSize: 9.sp,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  widget.weeklyData.length,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: widget.weeklyData[i],
                        width: 3.w,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: _touchedIndex == i
                              ? [_orange, _gold]
                              : [_primary.withValues(alpha: 0.6), _primary],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
