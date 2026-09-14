import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import '../data/remote/about_us_repository.dart';
import '../data/remote/supabase_service.dart';
import '../data/local/local_cache_service.dart';
import '../models/about_us_content.dart';
import '../widgets/my_darah_brand.dart';

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({
    super.key,
    this.canEdit = false,
    this.useDonorColors = false,
    this.useOrganisationColors = false,
    this.useHospitalColors = false,
    this.useSystemAdminColors = false,
  });

  final bool canEdit;
  final bool useDonorColors;
  final bool useOrganisationColors;
  final bool useHospitalColors;
  final bool useSystemAdminColors;

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  late Future<AboutUsContent> content = load();

  Future<AboutUsContent> load() {
    final client = SupabaseService.client;
    if (client == null) return Future.value(AboutUsRepository.fallback);
    return AboutUsRepository(client).getContent();
  }

  Color? get pageBackground => widget.useDonorColors
      ? AppTheme.donorBackground
      : widget.useOrganisationColors
      ? AppTheme.organisationBackground
      : widget.useHospitalColors
      ? AppTheme.hospitalBackground
      : widget.useSystemAdminColors
      ? AppTheme.systemAdminBackground
      : null;

  Color? get headerColor => widget.useDonorColors
      ? AppTheme.donorHeader
      : widget.useOrganisationColors
      ? AppTheme.organisationHeader
      : widget.useHospitalColors
      ? AppTheme.hospitalHeader
      : widget.useSystemAdminColors
      ? AppTheme.systemAdminHeader
      : null;

  TextStyle? get headerStyle => widget.useDonorColors
      ? AppTheme.donorHeaderTitleStyle
      : widget.useOrganisationColors
      ? AppTheme.organisationHeaderTitleStyle
      : widget.useHospitalColors
      ? AppTheme.hospitalHeaderTitleStyle
      : widget.useSystemAdminColors
      ? AppTheme.systemAdminHeaderTitleStyle
      : null;

  Future<void> edit(AboutUsContent current) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _EditAboutUsScreen(current: current)),
    );
    if (saved == true && mounted) {
      setState(() {
        content = load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: pageBackground,
    appBar: AppBar(
      backgroundColor: headerColor,
      foregroundColor: Colors.white,
      titleTextStyle: headerStyle,
      title: const Text('About Us'),
    ),
    body: FutureBuilder<AboutUsContent>(
      future: content,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to load About Us content.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => setState(() {
                      content = load();
                    }),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        final value = snapshot.data ?? AboutUsRepository.fallback;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: MyDarahMark(size: 96)),
                    const SizedBox(height: 16),
                    Text(
                      value.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 14),
                    Text(value.content),
                  ],
                ),
              ),
            ),
            if (widget.canEdit) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => edit(value),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.systemAdmin,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit About Us'),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _EditAboutUsScreen extends StatefulWidget {
  const _EditAboutUsScreen({required this.current});

  final AboutUsContent current;

  @override
  State<_EditAboutUsScreen> createState() => _EditAboutUsScreenState();
}

class _EditAboutUsScreenState extends State<_EditAboutUsScreen> {
  final formKey = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.current.title);
  late final body = TextEditingController(text: widget.current.content);
  bool saving = false;
  bool savedSuccessfully = false;

  @override
  void initState() {
    super.initState();
    restoreDraft();
  }

  Future<void> restoreDraft() async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) return;
    final draft = await LocalCacheService.instance.loadMap(
      userId,
      'about_us_draft',
    );
    if (!mounted || draft == null) return;
    setState(() {
      title.text = draft['title'] as String? ?? title.text;
      body.text = draft['content'] as String? ?? body.text;
    });
  }

  Future<void> saveDraft() async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) return;
    await LocalCacheService.instance.saveMap(userId, 'about_us_draft', {
      'title': title.text,
      'content': body.text,
    });
  }

  @override
  void dispose() {
    if (!savedSuccessfully) saveDraft();
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final client = SupabaseService.client;
    if (client == null) return;
    setState(() => saving = true);
    try {
      await AboutUsRepository(
        client,
      ).update(title: title.text, content: body.text);
      await LocalCacheService.instance.remove(
        client.auth.currentUser!.id,
        'about_us_draft',
      );
      savedSuccessfully = true;
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save About Us: $error')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.systemAdminBackground,
    appBar: AppBar(
      backgroundColor: AppTheme.systemAdminHeader,
      foregroundColor: Colors.white,
      titleTextStyle: AppTheme.systemAdminHeaderTitleStyle,
      title: const Text('Edit About Us'),
    ),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Page title'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a page title.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: body,
            minLines: 10,
            maxLines: 18,
            decoration: const InputDecoration(
              labelText: 'About Us content',
              alignLabelWithHint: true,
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter the About Us content.'
                : null,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saving ? null : save,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.systemAdmin,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.systemAdminPalette[1],
              disabledForegroundColor: AppTheme.systemAdminHeader,
            ),
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save About Us'),
          ),
        ],
      ),
    ),
  );
}
