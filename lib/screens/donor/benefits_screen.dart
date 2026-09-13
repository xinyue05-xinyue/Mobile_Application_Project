import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_theme.dart';

class DonorBenefitsScreen extends StatefulWidget {
  const DonorBenefitsScreen({
    super.key,
    required this.donationCount,
    required this.points,
  });

  final int donationCount;
  final int points;

  @override
  State<DonorBenefitsScreen> createState() => _DonorBenefitsScreenState();
}

class _DonorBenefitsScreenState extends State<DonorBenefitsScreen> {
  late final PageController controller;
  late int activePage;

  static const tiers = [
    ('Bronze', '1–5 verified donations', Color(0xFFB87333)),
    ('Silver', '6–15 verified donations', Color(0xFF8A949E)),
    ('Gold', '16+ verified donations', Color(0xFFD49A13)),
  ];

  @override
  void initState() {
    super.initState();
    activePage = widget.donationCount >= 16
        ? 2
        : widget.donationCount >= 6
        ? 1
        : 0;
    controller = PageController(initialPage: activePage, viewportFraction: .9);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> openOfficialSource(BuildContext context) async {
    final uri = Uri.parse('https://pdn.gov.my/v2/keistimewaan-penderma/');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the PDN information.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final donationCount = widget.donationCount;
    return Scaffold(
      backgroundColor: AppTheme.donorBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.donorHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.donorHeaderTitleStyle,
        title: const Text('My benefits & level'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 292,
            child: PageView.builder(
              controller: controller,
              itemCount: tiers.length,
              onPageChanged: (page) => setState(() => activePage = page),
              itemBuilder: (context, index) {
                final tier = tiers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _TierHero(
                    title: tier.$1,
                    range: tier.$2,
                    color: tier.$3,
                    donationCount: donationCount,
                    isCurrent:
                        index ==
                        (donationCount >= 16
                            ? 2
                            : donationCount >= 6
                            ? 1
                            : 0),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              tiers.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: index == activePage ? 22 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == activePage
                      ? tiers[activePage].$3
                      : Colors.black12,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${tiers[activePage].$1} MyDarah benefits',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text('Benefits available for this recognition level.'),
          const SizedBox(height: 10),
          _BenefitGroup(
            color: tiers[activePage].$3,
            benefits: _myDarahBenefits(activePage),
          ),
          const SizedBox(height: 24),
          Text(
            '${tiers[activePage].$1} official Malaysian privileges',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.health_and_safety_outlined,
                        color: Color(0xFF11845B),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _officialTierTitle(activePage),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            for (final benefit in _officialTierBenefits(
                              activePage,
                            ))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• '),
                                    Expanded(child: Text(benefit)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Present your official donor record and contact a blood bank for verification. MyDarah history does not replace BBISV2, MySejahtera or the official donor record.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF716568)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => openOfficialSource(context),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Read official PDN information'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierHero extends StatelessWidget {
  const _TierHero({
    required this.title,
    required this.range,
    required this.color,
    required this.donationCount,
    required this.isCurrent,
  });
  final String title;
  final String range;
  final Color color;
  final int donationCount;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final tierStart = title == 'Bronze'
        ? 1
        : title == 'Silver'
        ? 6
        : 16;
    final tierCapacity = title == 'Bronze'
        ? 5
        : title == 'Silver'
        ? 10
        : 16;
    final tierProgress = title == 'Bronze'
        ? donationCount.clamp(0, 5)
        : title == 'Silver'
        ? (donationCount - 5).clamp(0, 10)
        : donationCount.clamp(0, 16);
    final progress = (tierProgress / tierCapacity).clamp(0.0, 1.0);
    final isLocked = donationCount < tierStart;
    final isGoldCurrent = title == 'Gold' && isCurrent;
    final showProgress = !isLocked && title != 'Gold';
    final donationsNeeded = (tierStart - donationCount).clamp(0, tierStart);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: .7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .24),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCurrent && !isLocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .28),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'YOUR CURRENT LEVEL',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
            )
          else
            Text(
              isLocked ? 'LOCKED LEVEL' : 'LEVEL ACHIEVED',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Medal(level: title, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$title Donor',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                    ),
                    Text(range, style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isLocked
                  ? '$donationsNeeded more verified ${donationsNeeded == 1 ? 'donation' : 'donations'} to unlock $title'
                  : isCurrent
                  ? '$donationCount verified donation${donationCount == 1 ? '' : 's'}'
                  : 'Completed recognition level',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 13,
                color: Colors.white,
                backgroundColor: Colors.white30,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCurrent
                      ? title == 'Bronze'
                            ? 'Progress through Bronze'
                            : 'Progress through Silver'
                      : '$title completed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$tierProgress / $tierCapacity',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ] else if (isGoldCurrent) ...[
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You have reached the highest donor level.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

List<(IconData, String, String)> _myDarahBenefits(int tier) => switch (tier) {
  0 => const [
    (Icons.biotech_outlined, '5% off selected blood tests', ''),
    (
      Icons.medication_outlined,
      '5% off selected over-the-counter medicines',
      '',
    ),
    (Icons.health_and_safety_outlined, 'Discounted basic health screening', ''),
  ],
  1 => const [
    (Icons.biotech_outlined, '10% off selected blood tests', ''),
    (
      Icons.medication_outlined,
      '10% off selected over-the-counter medicines',
      '',
    ),
    (
      Icons.health_and_safety_outlined,
      'Free basic health screening once a year',
      '',
    ),
  ],
  _ => const [
    (Icons.biotech_outlined, 'Annual free basic blood test', ''),
    (
      Icons.medication_outlined,
      '15% off selected medicines and health products',
      '',
    ),
    (
      Icons.monitor_heart_outlined,
      'Annual comprehensive health screening at a special rate',
      '',
    ),
  ],
};

String _officialTierTitle(int tier) => switch (tier) {
  0 => 'PDN category: 1–5 donations',
  1 => 'PDN categories: 6–10 and 11–15 donations',
  _ => 'PDN categories beginning at 16 donations',
};

List<String> _officialTierBenefits(int tier) => switch (tier) {
  0 => const [
    'Free outpatient treatment, including dental and medical treatment, plus second-class ward treatment for 4 months.',
    'Two donations within 12 months may qualify for a free Hepatitis B preventive injection.',
  ],
  1 => const [
    '6–10 donations: outpatient, dental and medical treatment plus second-class ward treatment for 6 months.',
    '11–15 donations: the corresponding treatment privileges for 12 months.',
  ],
  _ => const [
    '16–20 donations: outpatient, dental and medical treatment plus second-class ward treatment for 24 months.',
    'Higher official donation categories provide longer periods and may progress to first-class ward privileges. Read the current PDN table for the exact category.',
  ],
};

class _BenefitGroup extends StatelessWidget {
  const _BenefitGroup({required this.color, required this.benefits});
  final Color color;
  final List<(IconData, String, String)> benefits;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        for (var index = 0; index < benefits.length; index++) ...[
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 7,
            ),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: .14),
              foregroundColor: color,
              child: Icon(benefits[index].$1),
            ),
            title: Text(benefits[index].$2),
            subtitle: benefits[index].$3.isEmpty
                ? null
                : Text(benefits[index].$3),
          ),
          if (index != benefits.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );
}

class _Medal extends StatelessWidget {
  const _Medal({required this.level, required this.color});
  final String level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 3,
        ),
      ),
      child: Icon(
        level == 'New donor'
            ? Icons.volunteer_activism_rounded
            : Icons.workspace_premium_rounded,
        size: 56,
        color: Colors.white,
      ),
    );
  }
}
