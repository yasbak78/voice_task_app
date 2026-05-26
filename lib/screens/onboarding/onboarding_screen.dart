import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_components.dart';
import '../../core/theme/app_themes.dart';
import '../../core/theme/theme_model.dart';
import '../../screens/main_shell.dart';

/// Onboarding screen shown on first app launch.
/// 4-slide PageView with theme picker, animated page indicators,
/// and SharedPreferences persistence.
class OnboardingScreen extends StatefulWidget {
  static const String route = '/onboarding';

  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;
  ThemeModel? _selectedTheme;
  bool _isCompleting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    // Apply selected theme (default to Morning Mist if none picked)
    final themeToSave = _selectedTheme ?? AppThemes.defaultTheme;
    await prefs.setString('selected_theme', themeToSave.id);

    if (!mounted) return;

    // Navigate to home — clear the stack so back button doesn't return here
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  void _selectTheme(ThemeModel theme) {
    setState(() => _selectedTheme = theme);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              children: [
                _buildWelcomeSlide(colorScheme),
                _buildHowItWorksSlide(colorScheme),
                _buildThemePickerSlide(colorScheme, theme),
                _buildGetStartedSlide(colorScheme, theme),
              ],
            ),
            // Skip button (not shown on last slide)
            if (_currentPage < 3)
              Positioned(
                top: AppSpacing.lg,
                right: AppSpacing.lg,
                child: AppButton(
                  label: 'Skip',
                  variant: ButtonVariant.text,
                  onPressed: _completeOnboarding,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Slide 1: Welcome ───────────────────────────────────────────

  Widget _buildWelcomeSlide(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          // App icon / emoji
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '🎤',
                style: const TextStyle(fontSize: 52),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Voice Tasks',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Record tasks with your voice,\npowered by AI transcription',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxxl),
          // Page indicators
          _buildPageIndicators(colorScheme),
          const Spacer(flex: 3),
          // Next button
          _buildNavigationButtons(colorScheme, theme, showBack: false),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  // ─── Slide 2: How it works ──────────────────────────────────────

  Widget _buildHowItWorksSlide(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),
          Text(
            'How it works',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Steps
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStep(
                  emoji: '🎤',
                  title: 'Record',
                  description: 'Tap the mic and speak your task naturally',
                  colorScheme: colorScheme,
                  theme: theme,
                ),
                _buildStepArrow(colorScheme),
                _buildStep(
                  emoji: '📝',
                  title: 'Transcribe',
                  description: 'AI converts your voice to text instantly',
                  colorScheme: colorScheme,
                  theme: theme,
                ),
                _buildStepArrow(colorScheme),
                _buildStep(
                  emoji: '✅',
                  title: 'Save',
                  description: 'Review, edit, and organize your tasks',
                  colorScheme: colorScheme,
                  theme: theme,
                ),
              ],
            ),
          ),
          // Page indicators
          _buildPageIndicators(colorScheme),
          const SizedBox(height: AppSpacing.lg),
          // Navigation buttons
          _buildNavigationButtons(colorScheme, theme, showBack: true),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String emoji,
    required String title,
    required String description,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepArrow(ColorScheme colorScheme) {
    return Icon(
      Icons.arrow_downward,
      color: colorScheme.primary.withValues(alpha: 0.5),
      size: 24,
    );
  }

  // ─── Slide 3: Theme Picker ──────────────────────────────────────

  Widget _buildThemePickerSlide(ColorScheme colorScheme, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),
          Text(
            'Choose your style',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Pick a color theme you like — you can always change it later',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          // Theme cards
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: AppThemes.all
                  .map((t) => _buildThemeCard(t, colorScheme, theme))
                  .toList()
                  .separated(const SizedBox(height: AppSpacing.md)),
            ),
          ),
          // Page indicators
          _buildPageIndicators(colorScheme),
          const SizedBox(height: AppSpacing.lg),
          // Navigation buttons
          _buildNavigationButtons(colorScheme, theme, showBack: true),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildThemeCard(
    ThemeModel themeModel,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final isSelected = _selectedTheme?.id == themeModel.id;
    return GestureDetector(
      onTap: () => _selectTheme(themeModel),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected
              ? themeModel.seedColor.withValues(alpha: 0.12)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(
            color: isSelected
                ? themeModel.seedColor
                : colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Color swatch
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: themeModel.seedColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: themeModel.seedColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                themeModel.icon,
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            // Theme name
            Expanded(
              child: Text(
                themeModel.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            // Selection indicator
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Icon(
                      Icons.check_circle,
                      key: const ValueKey('selected'),
                      color: themeModel.seedColor,
                      size: 28,
                    )
                  : Icon(
                      Icons.circle_outlined,
                      key: const ValueKey('unselected'),
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      size: 28,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Slide 4: Get Started ───────────────────────────────────────

  Widget _buildGetStartedSlide(ColorScheme colorScheme, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rocket_launch_outlined,
              size: 40,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Ready?',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Your tasks, organized by voice',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          // Get Started button
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Get Started',
              variant: ButtonVariant.filled,
              onPressed: _isCompleting ? null : _completeOnboarding,
              isLoading: _isCompleting,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Micropermission note
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'You\'ll be asked for microphone permission when you record your first task',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          // Page indicators
          _buildPageIndicators(colorScheme),
          const Spacer(flex: 1),
          // Back button only
          _buildNavigationButtons(colorScheme, theme, showBack: true, showNext: false),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  // ─── Shared: Page Indicators ────────────────────────────────────

  Widget _buildPageIndicators(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          width: isActive ? AppSpacing.xxl : AppSpacing.sm,
          height: AppSpacing.sm,
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        );
      }),
    );
  }

  // ─── Shared: Navigation Buttons ─────────────────────────────────

  Widget _buildNavigationButtons(
    ColorScheme colorScheme,
    ThemeData theme, {
    required bool showBack,
    bool showNext = true,
  }) {
    return Row(
      children: [
        if (showBack)
          Expanded(
            child: OutlinedButton(
              onPressed: _previousPage,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusLg),
                ),
                side: BorderSide(color: colorScheme.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Back',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (showBack && showNext) const SizedBox(width: AppSpacing.lg),
        if (showNext)
          Expanded(
            child: FilledButton(
              onPressed: _nextPage,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusLg),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Next',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Extension to insert separators between list items.
extension ListSeparator<T> on List<T> {
  List<T> separated(T separator) {
    if (isEmpty) return this;
    final result = <T>[];
    for (int i = 0; i < length; i++) {
      result.add(this[i]);
      if (i < length - 1) result.add(separator);
    }
    return result;
  }
}
