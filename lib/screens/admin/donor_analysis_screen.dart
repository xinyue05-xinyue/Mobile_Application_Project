import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/admin_dashboard_repository.dart';
import '../../data/remote/supabase_service.dart';

enum _AnalysisRange { lastFive, lastThreeMonths }

class DonorAnalysisScreen extends StatefulWidget {
  const DonorAnalysisScreen({super.key});

  @override
  State<DonorAnalysisScreen> createState() => _DonorAnalysisScreenState();
}

class _DonorAnalysisScreenState extends State<DonorAnalysisScreen> {
  _AnalysisRange range = _AnalysisRange.lastFive;
  late Future<List<AdminEventAnalytics>> analytics = load();

  Future<List<AdminEventAnalytics>> load() {
    final client = SupabaseService.client;
    if (client == null) return Future.value(const []);
    return AdminDashboardRepository(client).getEventAnalytics();
  }

  List<AdminEventAnalytics> selected(List<AdminEventAnalytics> all) {
    if (range == _AnalysisRange.lastFive) {
      return all.take(5).toList().reversed.toList();
    }
    final cutoff = DateTime.now().subtract(const Duration(days: 92));
    return all
        .where((event) => event.startsAt.isAfter(cutoff))
        .toList()
        .reversed
        .toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.organisationBackground,
    appBar: AppBar(
      backgroundColor: AppTheme.organisationHeader,
      foregroundColor: Colors.white,
      titleTextStyle: AppTheme.organisationHeaderTitleStyle,
      title: const Text('Donor analysis'),
    ),
    body: FutureBuilder<List<AdminEventAnalytics>>(
      future: analytics,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                analytics = load();
              }),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          );
        }
        final events = selected(snapshot.data ?? const []);
        final registrations = events.fold(
          0,
          (sum, event) => sum + event.registrations,
        );
        final verified = events.fold(0, (sum, event) => sum + event.verified);
        final groups = <String, int>{};
        for (final event in events) {
          for (final entry in event.bloodGroups.entries) {
            groups[entry.key] = (groups[entry.key] ?? 0) + entry.value;
          }
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            SegmentedButton<_AnalysisRange>(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppTheme.organisationPalette[1]
                      : Colors.transparent,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppTheme.organisationHeader
                      : AppTheme.ink,
                ),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: AppTheme.organisationHeader),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: _AnalysisRange.lastFive,
                  label: Text('Last 5 events'),
                ),
                ButtonSegment(
                  value: _AnalysisRange.lastThreeMonths,
                  label: Text('Past 3 months'),
                ),
              ],
              selected: {range},
              onSelectionChanged: (value) =>
                  setState(() => range = value.first),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    value: registrations,
                    label: 'Total registrations',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(value: verified, label: 'Verified donors'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Donors by event',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Registration and verified attendance for the selected period.',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 14),
                child: events.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('No event data in this period.'),
                        ),
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 220,
                            child: CustomPaint(
                              painter: _EventBarPainter(events),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          for (var index = 0; index < events.length; index++)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      events[index].title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Blood-type mix',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Linked to the same selected events and registrations above.',
            ),
            const SizedBox(height: 12),
            _BloodPieCard(groups: groups),
            const SizedBox(height: 12),
            const Text(
              'Upcoming and in-progress registrations are included so organisers can plan capacity. Verified totals remain separate, because those donors have actually attended.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        );
      },
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    ),
  );
}

class _EventBarPainter extends CustomPainter {
  const _EventBarPainter(this.events);
  final List<AdminEventAnalytics> events;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;
    final registered = Paint()..color = const Color(0xFFD76532);
    final verified = Paint()..color = const Color(0xFF6F9F65);
    const left = 30.0;
    const bottom = 28.0;
    canvas.drawLine(Offset(left, 4), Offset(left, size.height - bottom), axis);
    canvas.drawLine(
      Offset(left, size.height - bottom),
      Offset(size.width, size.height - bottom),
      axis,
    );
    final maxValue = math.max(
      1,
      events.fold<int>(
        0,
        (value, event) => math.max(value, event.registrations),
      ),
    );
    final slot = (size.width - left) / events.length;
    final barWidth = math.min(18.0, slot * .28);
    for (var i = 0; i < events.length; i++) {
      final centre = left + slot * (i + .5);
      final available = size.height - bottom - 34;
      final registrationHeight = available * events[i].registrations / maxValue;
      final verifiedHeight = available * events[i].verified / maxValue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centre - barWidth - 2,
            size.height - bottom - registrationHeight,
            barWidth,
            registrationHeight,
          ),
          const Radius.circular(5),
        ),
        registered,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centre + 2,
            size.height - bottom - verifiedHeight,
            barWidth,
            verifiedHeight,
          ),
          const Radius.circular(5),
        ),
        verified,
      );
      _paintValue(
        canvas,
        '${events[i].registrations}',
        centre - barWidth / 2 - 2,
        size.height - bottom - registrationHeight - 18,
        const Color(0xFFC84A1F),
      );
      _paintValue(
        canvas,
        '${events[i].verified}',
        centre + barWidth / 2 + 2,
        size.height - bottom - verifiedHeight - 18,
        const Color(0xFF3F8A52),
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(centre - label.width / 2, size.height - bottom + 7),
      );
    }
  }

  void _paintValue(
    Canvas canvas,
    String value,
    double centre,
    double top,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(centre - painter.width / 2, math.max(0, top)));
  }

  @override
  bool shouldRepaint(covariant _EventBarPainter oldDelegate) =>
      oldDelegate.events != events;
}

class _BloodPieCard extends StatelessWidget {
  const _BloodPieCard({required this.groups});
  final Map<String, int> groups;

  static const colors = [
    Color(0xFFD76532),
    Color(0xFFD94478),
    Color(0xFF806F72),
    Color(0xFFF0A65B),
    Color(0xFF6F9F65),
    Color(0xFF7D78B8),
    Color(0xFFBB7C68),
    Color(0xFF4E8D9B),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = groups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No blood-type data in this period.')),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(painter: _PiePainter(entries, colors)),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Wrap(
                runSpacing: 8,
                children: [
                  for (var i = 0; i < entries.length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors[i % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${entries[i].key}  ${entries[i].value}'),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  const _PiePainter(this.entries, this.colors);
  final List<MapEntry<String, int>> entries;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
    var start = -math.pi / 2;
    final rect = Offset.zero & size;
    for (var i = 0; i < entries.length; i++) {
      final sweep = math.pi * 2 * entries[i].value / total;
      canvas.drawArc(
        rect.deflate(8),
        start,
        sweep,
        true,
        Paint()..color = colors[i % colors.length],
      );
      start += sweep;
    }
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide * .22,
      Paint()..color = ThemeData.light().scaffoldBackgroundColor,
    );
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) =>
      oldDelegate.entries != entries;
}
