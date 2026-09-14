import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../data/remote/reward_repository.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/local/local_cache_service.dart';
import '../../models/reward_item.dart';
import '../../widgets/reward_visual.dart';

class ManageRewardsScreen extends StatefulWidget {
  const ManageRewardsScreen({super.key});

  @override
  State<ManageRewardsScreen> createState() => _ManageRewardsScreenState();
}

class _ManageRewardsScreenState extends State<ManageRewardsScreen> {
  late Future<List<RewardItem>> items;
  String selectedStatus = 'all';

  RewardRepository get repository => RewardRepository(
    SupabaseService.client ?? (throw StateError('Supabase is not configured.')),
  );

  @override
  void initState() {
    super.initState();
    items = repository.getAllItems();
  }

  Future<void> refresh() async {
    final refreshed = repository.getAllItems();
    setState(() {
      items = refreshed;
    });
    await refreshed;
  }

  Future<void> openForm([RewardItem? item]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RewardFormScreen(item: item)),
    );
    if (changed == true && mounted) await refresh();
  }

  Future<void> remove(RewardItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hide reward?'),
        content: Text(
          '${item.name} will disappear from the donor catalogue. Existing '
          'redemption records will be kept for audit and collection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hide reward'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repository.archiveItem(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reward hidden.')));
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to remove reward: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.systemAdminBackground,
    appBar: AppBar(
      backgroundColor: AppTheme.systemAdminHeader,
      foregroundColor: Colors.white,
      titleTextStyle: AppTheme.systemAdminHeaderTitleStyle,
      title: const Text('Manage redeem rewards'),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: openForm,
      icon: const Icon(Icons.add),
      label: const Text('Create reward'),
    ),
    body: FutureBuilder<List<RewardItem>>(
      future: items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton.icon(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Unable to load rewards. Try again'),
            ),
          );
        }
        final allRewards = snapshot.data!;
        final rewards = switch (selectedStatus) {
          'active' => allRewards.where((item) => item.isActive).toList(),
          'inactive' => allRewards.where((item) => !item.isActive).toList(),
          _ => allRewards,
        };
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: ['all', 'active', 'inactive']
                    .map(
                      (status) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            '${status[0].toUpperCase()}${status.substring(1)}',
                          ),
                          selected: selectedStatus == status,
                          onSelected: (_) => setState(() {
                            selectedStatus = status;
                          }),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: refresh,
                child: rewards.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 150),
                          const Icon(Icons.redeem_outlined, size: 58),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              selectedStatus == 'all'
                                  ? 'No rewards have been created.'
                                  : 'No $selectedStatus rewards.',
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: rewards.length,
                        itemBuilder: (context, index) {
                          final item = rewards[index];
                          return Card(
                            color: item.isActive
                                ? null
                                : Colors.black.withValues(alpha: .04),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RewardVisual(item: item, size: 72),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.name,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleMedium,
                                              ),
                                            ),
                                            if (!item.isActive)
                                              const Chip(
                                                label: Text('INACTIVE'),
                                              ),
                                          ],
                                        ),
                                        Text(
                                          item.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${item.pointsCost} points • ${item.stockQuantity} available',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () => openForm(item),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                              label: const Text('Edit'),
                                            ),
                                            const SizedBox(width: 8),
                                            if (item.isActive)
                                              TextButton.icon(
                                                onPressed: () => remove(item),
                                                icon: const Icon(
                                                  Icons.visibility_off_outlined,
                                                ),
                                                label: const Text('Hide'),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class RewardFormScreen extends StatefulWidget {
  const RewardFormScreen({super.key, this.item});

  final RewardItem? item;

  @override
  State<RewardFormScreen> createState() => _RewardFormScreenState();
}

class _RewardFormScreenState extends State<RewardFormScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController description;
  late final TextEditingController points;
  late final TextEditingController stock;
  late String category;
  late String iconKey;
  late bool isActive;
  String? imageUrl;
  Uint8List? selectedImage;
  String? selectedFileName;
  bool saving = false;
  bool savedSuccessfully = false;

  RewardRepository get repository => RewardRepository(
    SupabaseService.client ?? (throw StateError('Supabase is not configured.')),
  );

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    name = TextEditingController(text: item?.name);
    description = TextEditingController(text: item?.description);
    points = TextEditingController(text: item?.pointsCost.toString());
    stock = TextEditingController(text: item?.stockQuantity.toString() ?? '0');
    category = item?.category ?? 'merchandise';
    final savedIcon = item?.iconKey;
    iconKey = rewardIconChoices.any((choice) => choice.$1 == savedIcon)
        ? savedIcon!
        : 'gift';
    isActive = item?.isActive ?? true;
    imageUrl = item?.imageUrl;
    restoreDraft();
  }

  String get draftName => 'reward_draft_${widget.item?.id ?? 'new'}';

  Future<void> restoreDraft() async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) return;
    final draft = await LocalCacheService.instance.loadMap(userId, draftName);
    if (!mounted || draft == null) return;
    setState(() {
      name.text = draft['name'] as String? ?? name.text;
      description.text = draft['description'] as String? ?? description.text;
      points.text = draft['points'] as String? ?? points.text;
      stock.text = draft['stock'] as String? ?? stock.text;
      category = draft['category'] as String? ?? category;
      iconKey = draft['icon_key'] as String? ?? iconKey;
      isActive = draft['is_active'] as bool? ?? isActive;
      imageUrl = draft['image_url'] as String? ?? imageUrl;
    });
  }

  Future<void> saveDraft() async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) return;
    await LocalCacheService.instance.saveMap(userId, draftName, {
      'name': name.text,
      'description': description.text,
      'points': points.text,
      'stock': stock.text,
      'category': category,
      'icon_key': iconKey,
      'is_active': isActive,
      'image_url': imageUrl,
    });
  }

  @override
  void dispose() {
    if (!savedSuccessfully) saveDraft();
    name.dispose();
    description.dispose();
    points.dispose();
    stock.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result.isEmpty || !mounted) return;
    final file = result.single;
    if (await file.length() > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reward image must be 5 MB or smaller.')),
      );
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      selectedImage = bytes;
      selectedFileName = file.name;
    });
  }

  String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  String? positiveNumber(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number <= 0 ? 'Enter a number above 0.' : null;
  }

  String? stockNumber(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 0 ? 'Enter 0 or a higher number.' : null;
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      var savedImageUrl = imageUrl;
      if (selectedImage != null) {
        savedImageUrl = await repository.uploadImage(
          fileName: selectedFileName!,
          bytes: selectedImage!,
        );
      }
      final item = widget.item;
      if (item == null) {
        await repository.createItem(
          name: name.text.trim(),
          description: description.text.trim(),
          category: category,
          pointsCost: int.parse(points.text),
          stockQuantity: int.parse(stock.text),
          iconKey: iconKey,
          imageUrl: savedImageUrl,
        );
      } else {
        await repository.updateItem(
          id: item.id,
          name: name.text.trim(),
          description: description.text.trim(),
          category: category,
          pointsCost: int.parse(points.text),
          stockQuantity: int.parse(stock.text),
          iconKey: iconKey,
          imageUrl: savedImageUrl,
          isActive: isActive,
        );
      }
      await LocalCacheService.instance.remove(
        SupabaseService.client!.auth.currentUser!.id,
        draftName,
      );
      savedSuccessfully = true;
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save reward: $error')));
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.systemAdminBackground,
    appBar: AppBar(
      backgroundColor: AppTheme.systemAdminHeader,
      foregroundColor: Colors.white,
      titleTextStyle: AppTheme.systemAdminHeaderTitleStyle,
      title: Text(widget.item == null ? 'Create reward' : 'Edit reward'),
    ),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: name,
            validator: requiredText,
            decoration: const InputDecoration(labelText: 'Reward name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: description,
            validator: requiredText,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: points,
                  validator: positiveNumber,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Points needed'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: stock,
                  validator: stockNumber,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Available quantity',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Reward category'),
            items: const [
              DropdownMenuItem(
                value: 'merchandise',
                child: Text('Merchandise'),
              ),
              DropdownMenuItem(value: 'voucher', child: Text('Voucher')),
            ],
            onChanged: (value) => setState(() => category = value!),
          ),
          const SizedBox(height: 18),
          Text('Reward icon', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: rewardIconChoices
                .map(
                  (choice) => ChoiceChip(
                    selected: iconKey == choice.$1,
                    avatar: Icon(choice.$3, size: 18),
                    label: Text(choice.$2),
                    onSelected: (_) => setState(() => iconKey = choice.$1),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          Text(
            'Reward image (optional)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (selectedImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                selectedImage!,
                height: 180,
                fit: BoxFit.cover,
              ),
            )
          else if (imageUrl case final url?)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(url, height: 180, fit: BoxFit.cover),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.upload_outlined),
                label: Text(
                  imageUrl == null && selectedImage == null
                      ? 'Upload image'
                      : 'Replace image',
                ),
              ),
              if (imageUrl != null || selectedImage != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() {
                    imageUrl = null;
                    selectedImage = null;
                    selectedFileName = null;
                  }),
                  child: const Text('Remove image'),
                ),
              ],
            ],
          ),
          if (widget.item != null) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible to donors'),
              subtitle: const Text(
                'Inactive rewards remain in redemption history.',
              ),
              value: isActive,
              onChanged: (value) => setState(() => isActive = value),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Saving…' : 'Save reward'),
          ),
        ],
      ),
    ),
  );
}
