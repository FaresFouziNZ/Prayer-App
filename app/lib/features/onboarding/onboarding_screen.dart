import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../config/settings_keys.dart';
import '../../l10n/app_localizations.dart';

/// First-launch carousel introducing the app's main features. Shown once —
/// skipping or finishing it sets [SettingsKeys.onboardingComplete], which
/// main() checks before choosing the router's initial location.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref
        .read(settingsRepositoryProvider)
        .setBool(SettingsKeys.onboardingComplete, true);
    if (mounted) context.go('/home');
  }

  void _next(int pageCount) {
    if (_page == pageCount - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final pages = [
      _OnboardingPageData(
        icon: Icons.mosque_rounded,
        title: l10n.onboardingWelcomeTitle,
        body: l10n.onboardingWelcomeBody,
        container: scheme.primaryContainer,
        onContainer: scheme.onPrimaryContainer,
      ),
      _OnboardingPageData(
        icon: Icons.schedule_rounded,
        title: l10n.onboardingTimesTitle,
        body: l10n.onboardingTimesBody,
        container: scheme.tertiaryContainer,
        onContainer: scheme.onTertiaryContainer,
      ),
      _OnboardingPageData(
        icon: Icons.fact_check_rounded,
        title: l10n.onboardingTrackTitle,
        body: l10n.onboardingTrackBody,
        container: scheme.primaryContainer,
        onContainer: scheme.onPrimaryContainer,
      ),
      _OnboardingPageData(
        icon: Icons.nights_stay_rounded,
        title: l10n.onboardingRamadanTitle,
        body: l10n.onboardingRamadanBody,
        container: scheme.secondaryContainer,
        onContainer: scheme.onSecondaryContainer,
      ),
    ];
    final isLast = _page == pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Visibility(
                  visible: !isLast,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(l10n.onboardingSkip),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _OnboardingPage(data: pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? scheme.primary
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _next(pages.length),
                  child: Text(
                    isLast ? l10n.onboardingGetStarted : l10n.onboardingNext,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String body;
  final Color container;
  final Color onContainer;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.body,
    required this.container,
    required this.onContainer,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: data.container,
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 56, color: data.onContainer),
          ),
          const SizedBox(height: 32),
          Text(
            data.title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            data.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
