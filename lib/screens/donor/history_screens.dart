import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../models/donation_record.dart';
import '../../models/reward_transaction.dart';
import '../../data/remote/supabase_service.dart';
import '../../widgets/event_schedule.dart';

Future<Map<String, String>> donationDetails(DonationRecord donation) async {
  final result = <String, String>{
    'Donation type': donation.sourceLabel,
    'Donation date': _dateLabel(donation.donationDate),
    'Verification': donation.verificationStatus,
  };
  final client = SupabaseService.client;
  if (client == null) throw StateError('Please log in to load details.');
  if (donation.eventId != null) {
    final row = await client
        .from('donation_events')
        .select('title, venue, starts_at, ends_at, description')
        .eq('id', donation.eventId!)
        .maybeSingle();
    if (row != null) {
      result['Event'] = row['title'] as String;
      result['Venue'] = row['venue'] as String;
      result['Schedule'] = eventSchedule(
        DateTime.parse(row['starts_at'] as String),
        DateTime.parse(row['ends_at'] as String),
      );
      if (row['description'] != null) {
        result['About the event'] = row['description'] as String;
      }
    } else {
      result['Event details'] = 'No longer available.';
    }
  } else if (donation.emergencyRequestId != null) {
    final row = await client
        .from('emergency_requests')
        .select('blood_type, urgency, deadline, status')
        .eq('id', donation.emergencyRequestId!)
        .maybeSingle();
    if (row != null) {
      result['Requested blood type'] = '${row['blood_type']}';
      result['Urgency'] = '${row['urgency']}';
      result['Request deadline'] = eventDateTime(
        DateTime.parse(row['deadline'] as String),
      );
      result['Request status'] = '${row['status']}';
    } else {
      result['Request details'] = 'No longer available.';
    }
  }
  return result;
}

Future<Map<String, String>> rewardDetails(RewardTransaction reward) async {
  final result = <String, String>{
    'Transaction type': reward.transactionType,
    'Points': '${reward.points > 0 ? '+' : ''}${reward.points}',
    'Date and time': eventDateTime(reward.createdAt),
    'Transaction reference': reward.id,
    'Explanation': reward.transactionType == 'redeemed'
        ? 'Points spent on a reward. Your donation-based level is unchanged. See Browse rewards for your redemption code and item.'
        : reward.transactionType == 'earned'
        ? 'Points awarded for a verified donation.'
        : 'A points adjustment.',
  };
  final client = SupabaseService.client;
  if (client != null) {
    final row = await client
        .from('reward_transactions')
        .select()
        .eq('id', reward.id)
        .maybeSingle();
    if (row?['reward_item_name'] != null) {
      result['Redeemed item'] = '${row!['reward_item_name']}';
      result['Explanation'] =
          'Redeemed ${row['reward_item_name']} for ${reward.points.abs()} points. Your donor level is unchanged.';
    }
    if (row?['redemption_id'] != null) {
      final redemption = await client
          .from('reward_redemptions')
          .select('redemption_code, status')
          .eq('id', row!['redemption_id'])
          .maybeSingle();
      if (redemption != null) {
        result['Redemption code'] = '${redemption['redemption_code']}';
        result['Redemption status'] = '${redemption['status']}';
      }
    }
    if (row?['donation_id'] != null) {
      final donation = await client
          .from('donations')
          .select(
            'id, donation_date, verification_status, event_id, emergency_request_id',
          )
          .eq('id', row!['donation_id'])
          .maybeSingle();
      if (donation != null) {
        result.addAll(await donationDetails(DonationRecord.fromMap(donation)));
      }
    }
  }
  return result;
}

class HistoryDetailScreen extends StatefulWidget {
  const HistoryDetailScreen({
    super.key,
    required this.title,
    required this.load,
  });
  final String title;
  final Future<Map<String, String>> Function() load;
  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  late Future<Map<String, String>> details = widget.load();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.donorBackground,
    appBar: AppBar(
      backgroundColor: AppTheme.donorHeader,
      foregroundColor: Colors.white,
      titleTextStyle: AppTheme.donorHeaderTitleStyle,
      title: Text(widget.title),
    ),
    body: FutureBuilder<Map<String, String>>(
      future: details,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unable to load details. Please check your connection.',
                ),
                TextButton(
                  onPressed: () => setState(() {
                    details = widget.load();
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final entry in snapshot.data!.entries)
              Card(
                child: ListTile(
                  title: Text(entry.key),
                  subtitle: Text(entry.value),
                ),
              ),
          ],
        );
      },
    ),
  );
}

String _dateLabel(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

class DonationHistoryScreen extends StatelessWidget {
  const DonationHistoryScreen({super.key, required this.donations});

  final List<DonationRecord> donations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.donorBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.donorHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.donorHeaderTitleStyle,
        title: const Text('Donation history'),
      ),
      body: donations.isEmpty
          ? const Center(child: Text('No donation records yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: donations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final donation = donations[index];
                final emergency = donation.emergencyRequestId != null;
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      child: Icon(
                        emergency
                            ? Icons.emergency_outlined
                            : Icons.bloodtype_outlined,
                      ),
                    ),
                    title: Text(donation.sourceLabel),
                    subtitle: Text(
                      '${_dateLabel(donation.donationDate)}\n'
                      'Status: ${donation.verificationStatus}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HistoryDetailScreen(
                          title: donation.sourceLabel,
                          load: () => donationDetails(donation),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class RewardHistoryScreen extends StatelessWidget {
  const RewardHistoryScreen({super.key, required this.rewards});

  final List<RewardTransaction> rewards;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.donorBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.donorHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.donorHeaderTitleStyle,
        title: const Text('Reward history'),
      ),
      body: rewards.isEmpty
          ? const Center(child: Text('No reward transactions yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rewards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final reward = rewards[index];
                final earned = reward.points >= 0;
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      child: Icon(earned ? Icons.add : Icons.redeem_outlined),
                    ),
                    title: Text(
                      '${reward.points > 0 ? '+' : ''}${reward.points} points',
                    ),
                    subtitle: Text(
                      '${earned ? 'Points earned' : 'Reward redeemed'}\n'
                      '${_dateLabel(reward.createdAt)}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HistoryDetailScreen(
                          title: 'Reward details',
                          load: () => rewardDetails(reward),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
