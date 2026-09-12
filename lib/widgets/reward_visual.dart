import 'package:flutter/material.dart';

import '../models/reward_item.dart';

const rewardIconChoices = <(String, String, IconData)>[
  ('voucher', 'Voucher', Icons.confirmation_number_outlined),
  ('gift', 'Gift', Icons.card_giftcard_outlined),
  ('shirt', 'T-shirt', Icons.checkroom_outlined),
];

IconData rewardIcon(String key) {
  for (final choice in rewardIconChoices) {
    if (choice.$1 == key) return choice.$3;
  }
  return Icons.card_giftcard_outlined;
}

class RewardVisual extends StatelessWidget {
  const RewardVisual({super.key, required this.item, this.size = 54});

  final RewardItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.primaryContainer,
        child: imageUrl == null || imageUrl.isEmpty
            ? Icon(
                rewardIcon(item.iconKey),
                color: Theme.of(context).colorScheme.primary,
                size: size * .48,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  rewardIcon(item.iconKey),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
      ),
    );
  }
}
