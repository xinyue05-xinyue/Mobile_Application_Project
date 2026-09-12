import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/reward_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../models/reward_item.dart';
import '../../models/reward_redemption.dart';
import '../../widgets/reward_visual.dart';

class RewardStoreScreen extends StatefulWidget {
  const RewardStoreScreen({super.key});

  @override
  State<RewardStoreScreen> createState() => _RewardStoreScreenState();
}

class _RewardStoreScreenState extends State<RewardStoreScreen> {
  late Future<_RewardStoreData> data;

  RewardRepository? get repository {
    final client = SupabaseService.client;
    return client == null ? null : RewardRepository(client);
  }

  @override
  void initState() {
    super.initState();
    data = loadData();
  }

  Future<_RewardStoreData> loadData() async {
    final repo = repository;
    if (repo == null) return const _RewardStoreData(0, [], []);
    final results = await Future.wait([
      repo.getBalance(),
      repo.getItems(),
      repo.getMine(),
    ]);
    return _RewardStoreData(
      results[0] as int,
      results[1] as List<RewardItem>,
      results[2] as List<RewardRedemption>,
    );
  }

  Future<void> openDetails(RewardItem item, int balance) async {
    final redeemed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RewardDetailScreen(item: item, balance: balance),
      ),
    );
    if (redeemed == true && mounted) {
      setState(() {
        data = loadData();
      });
    }
  }

  String dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.donorBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.donorHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.donorHeaderTitleStyle,
        title: const Text('Redeem Rewards'),
      ),
      body: FutureBuilder<_RewardStoreData>(
        future: data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load rewards: ${snapshot.error}'),
            );
          }
          final value = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              final refreshed = loadData();
              setState(() {
                data = refreshed;
              });
              await refreshed;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.stars, size: 36),
                    title: Text('${value.balance} available points'),
                    subtitle: const Text(
                      'A verified donation earns 100 points.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reward catalogue',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...value.items.map((item) {
                  final inStock = item.stockQuantity > 0;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              RewardVisual(item: item, size: 58),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              Text('${item.pointsCost} pts'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(item.description),
                          const SizedBox(height: 8),
                          Text(
                            inStock
                                ? '${item.stockQuantity} available'
                                : 'Out of stock',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => openDetails(item, value.balance),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('View details'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                Text(
                  'My redemptions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (value.redemptions.isEmpty)
                  const Card(
                    child: ListTile(title: Text('No rewards redeemed yet.')),
                  )
                else
                  ...value.redemptions.map(
                    (redemption) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.redeem_outlined),
                        title: Text(redemption.rewardName),
                        subtitle: Text(
                          '${redemption.pointsSpent} points • ${dateLabel(redemption.createdAt)}\n'
                          'Code: ${redemption.code}',
                        ),
                        trailing: Text(redemption.status.toUpperCase()),
                        isThreeLine: true,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class RewardDetailScreen extends StatefulWidget {
  const RewardDetailScreen({
    super.key,
    required this.item,
    required this.balance,
  });

  final RewardItem item;
  final int balance;

  @override
  State<RewardDetailScreen> createState() => _RewardDetailScreenState();
}

class _RewardDetailScreenState extends State<RewardDetailScreen> {
  bool redeeming = false;

  RewardRepository get repository => RewardRepository(
    SupabaseService.client ?? (throw StateError('Supabase is not configured.')),
  );

  Future<void> redeem() async {
    final item = widget.item;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.donorBackground,
        title: const Text('Redeem reward?'),
        content: Text(
          '${item.name} costs ${item.pointsCost} points. Your balance after '
          'redemption will be ${widget.balance - item.pointsCost} points.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => redeeming = true);
    try {
      final result = await repository.redeem(item.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.donorBackground,
          title: const Text('Reward redeemed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.redeem, size: 52),
              const SizedBox(height: 12),
              Text(item.name, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text('Redemption code'),
              SelectableText(
                result.code,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('${result.remainingPoints} points remaining'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() => redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final inStock = item.stockQuantity > 0;
    final canAfford = widget.balance >= item.pointsCost;
    return Scaffold(
      backgroundColor: AppTheme.donorBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.donorHeader,
        foregroundColor: Colors.white,
        titleTextStyle: AppTheme.donorHeaderTitleStyle,
        title: const Text('Reward details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (item.imageUrl case final imageUrl?)
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Center(child: RewardVisual(item: item, size: 150)),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: RewardVisual(item: item, size: 150)),
                  ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(item.description),
                      const SizedBox(height: 18),
                      _RewardDetailRow(
                        icon: Icons.stars_outlined,
                        label: 'Points needed',
                        value: '${item.pointsCost} points',
                      ),
                      const SizedBox(height: 10),
                      _RewardDetailRow(
                        icon: Icons.inventory_2_outlined,
                        label: 'Availability',
                        value: inStock
                            ? '${item.stockQuantity} available'
                            : 'Out of stock',
                      ),
                      const SizedBox(height: 10),
                      _RewardDetailRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Your balance',
                        value: '${widget.balance} points',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: !canAfford || !inStock || redeeming ? null : redeem,
              child: redeeming
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      !inStock
                          ? 'Out of stock'
                          : canAfford
                          ? 'Redeem for ${item.pointsCost} points'
                          : 'Not enough points',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardDetailRow extends StatelessWidget {
  const _RewardDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 10),
      Expanded(child: Text(label)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}

class _RewardStoreData {
  const _RewardStoreData(this.balance, this.items, this.redemptions);

  final int balance;
  final List<RewardItem> items;
  final List<RewardRedemption> redemptions;
}
