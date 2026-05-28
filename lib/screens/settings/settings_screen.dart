import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_task_app/core/haptics/app_haptics.dart';
import 'package:voice_task_app/core/theme/app_spacing.dart';
import 'package:voice_task_app/config/ai_config.dart';
import 'package:voice_task_app/services/ai_client.dart';
import 'package:voice_task_app/config/tts_config.dart';
import 'package:voice_task_app/services/tts_service.dart';
import 'package:voice_task_app/services/token_tracker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:voice_task_app/widgets/update_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _aiStatus = 'Not tested';
  String _aiStatusDetail = '';
  bool _testingAI = false;
  String _ttsStatus = 'Ready';
  bool _testingTTS = false;
  TokenSummary? _tokenSummary;
  bool _loadingUsage = false;
  Map<String, int> _todayUsage = {};
  bool _checkingUpdate = false;
  String _currentVersion = '';

  @override
  void initState() {
    super.initState();
    _loadTokenUsage();
    _getCurrentVersion();
  }

  Future<void> _getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentVersion = packageInfo.version;
        });
      }
    } catch (e) {
      print('Error getting app version: $e');
    }
  }

  Future<void> _loadTokenUsage() async {
    setState(() => _loadingUsage = true);
    try {
      final summary = await TokenTracker.getSummary();
      final todayUsage = await TokenTracker.getTodayUsageByProvider();
      if (mounted) {
        setState(() {
          _tokenSummary = summary;
          _todayUsage = todayUsage;
        });
      }
    } catch (_) {
      // silently ignore
    } finally {
      if (mounted) setState(() => _loadingUsage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sectionHeaderStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.grey,
      letterSpacing: 1.2,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: [
          // ── AI Provider ──
          _buildSectionHeader('AI PROVIDER', sectionHeaderStyle),
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  leading: Icon(Icons.smart_toy, color: colorScheme.primary),
                  title: const Text('Active Provider'),
                  subtitle: Text(AIConfig.activeLabel),
                  trailing: PopupMenuButton<AIProvider>(
                    icon: const Icon(Icons.swap_horiz),
                    tooltip: 'Switch provider',
                    itemBuilder: (context) => AIProvider.values
                        .map((p) => _providerPopupItem(p))
                        .toList(),
                    onSelected: _switchProvider,
                  ),
                ),
                const Divider(height: 1, thickness: 0.5),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  leading: Icon(Icons.security, color: colorScheme.primary),
                  title: Text('Fallback Chain'),
                  subtitle: Text(
                    AIConfig.fallbackOrder
                        .map((p) => p.name)
                        .join(' → '),
                  ),
                ),
                const Divider(height: 1, thickness: 0.5),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  leading: Icon(
                    _aiStatus == 'Connected'
                        ? Icons.check_circle
                        : _aiStatus == 'Error'
                            ? Icons.error
                            : Icons.wifi_find,
                    color: _aiStatus == 'Connected'
                        ? Colors.green
                        : _aiStatus == 'Error'
                            ? Colors.red
                            : Colors.orange,
                  ),
                  title: const Text('AI Connection'),
                  subtitle: Text(
                    _testingAI ? 'Testing...' : _aiStatusDetail,
                  ),
                  trailing: _testingAI
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _testAIConnection,
                          tooltip: 'Test connection',
                        ),
                ),
              ],
            ),
          ),

          const Divider(height: AppSpacing.lg, thickness: 0.5),

          // ── Voice / TTS ──
          _buildSectionHeader('VOICE & TTS', sectionHeaderStyle),
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  leading: Icon(Icons.model_training,
                      color: colorScheme.primary),
                  title: const Text('STT Model'),
                  subtitle: const Text('whisper.cpp tiny.en-q5_1'),
                ),
                const Divider(height: 1, thickness: 0.5),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  leading: Icon(Icons.volume_up, color: colorScheme.primary),
                  title: const Text('TTS Engine'),
                  subtitle: Text(TtsConfig.voiceSummary),
                ),
                const Divider(height: 1, thickness: 0.5),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  leading: Icon(
                    _ttsStatus == 'Ready'
                        ? Icons.check_circle
                        : Icons.warning,
                    color:
                        _ttsStatus == 'Ready' ? Colors.green : Colors.orange,
                  ),
                  title: const Text('TTS Status'),
                  subtitle: Text(_testingTTS ? 'Testing...' : _ttsStatus),
                  trailing: _testingTTS
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: _testTTS,
                          tooltip: 'Test voice',
                        ),
                ),
              ],
            ),
          ),

          const Divider(height: AppSpacing.lg, thickness: 0.5),

          // ── Token Usage ──
          _buildSectionHeader('TOKEN USAGE (LAST 7 DAYS)', sectionHeaderStyle),
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  leading: Icon(Icons.analytics, color: colorScheme.primary),
                  title: _loadingUsage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _tokenSummary?.requestCount == null
                              ? 'No usage yet'
                              : '${_tokenSummary!.requestCount} requests',
                        ),
                  subtitle: Text(
                    _tokenSummary != null
                        ? '${TokenSummary.formatTokens(_tokenSummary!.totalTokens)} tokens total'
                        : 'Start using AI to see usage',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadTokenUsage,
                    tooltip: 'Refresh',
                  ),
                ),
                if (_tokenSummary != null && _tokenSummary!.byProvider.isNotEmpty)
                  ...(_tokenSummary!.byProvider.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value)))
                      .map((e) {
                        final config = AIConfig.configByLabel(e.key) ??
                            const ProviderConfig(
                              baseUrl: '', apiKey: '', model: '', label: '',
                            );
                        final todayTokens = _todayUsage[e.key] ?? 0;
                        final budget = config.dailyTokenBudget;
                        final fraction = budget > 0
                            ? (todayTokens / budget).clamp(0.0, 1.0)
                            : null;
                        return _buildProviderUsage(
                          label: e.key,
                          totalTokens: e.value,
                          todayTokens: todayTokens,
                          budget: budget,
                          fraction: fraction,
                        );
                      }),
                if (_tokenSummary != null &&
                    _tokenSummary!.byPurpose.isNotEmpty)
                  ...(_tokenSummary!.byPurpose.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value)))
                      .map((e) => ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            leading: const Icon(Icons.category, size: 20),
                            title: Text(e.key),
                            trailing: Text('${e.value} requests'),
                          )),
                const Divider(height: 1, thickness: 0.5),
                if (_tokenSummary != null && _tokenSummary!.totalTokens > 0)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    leading: const Icon(Icons.info_outline, size: 20),
                    title: const Text('Breakdown'),
                    subtitle: Text(
                      'Prompt: ${TokenSummary.formatTokens(_tokenSummary!.promptTokens)} · '
                      'Completion: ${TokenSummary.formatTokens(_tokenSummary!.completionTokens)}',
                    ),
                  ),
                if (_tokenSummary != null && _tokenSummary!.totalTokens > 0)
                  const Divider(height: 1, thickness: 0.5),
                if (_tokenSummary != null && _tokenSummary!.totalTokens > 0)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    leading: Icon(Icons.delete_outline,
                        color: colorScheme.error),
                    title: const Text('Clear Usage Data'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await TokenTracker.clear();
                      if (mounted) setState(() => _tokenSummary = null);
                      AppHaptics.tap();
                    },
                  ),
              ],
            ),
          ),

          const Divider(height: AppSpacing.lg, thickness: 0.5),

          // ── Notifications ──
          _buildSectionHeader('NOTIFICATIONS', sectionHeaderStyle),
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  secondary: Icon(Icons.mic_outlined,
                      color: colorScheme.primary),
                  title: const Text('Use Silero VAD'),
                  subtitle: const Text('Skip silence during recording'),
                  value: true,
                  onChanged: (v) {
                    AppHaptics.tap();
                  },
                ),
              ],
            ),
          ),

          const Divider(height: AppSpacing.lg, thickness: 0.5),

          // ── About ──
          _buildSectionHeader('ABOUT', sectionHeaderStyle),
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  leading: Icon(Icons.info_outline, color: colorScheme.primary),
                  title: const Text('App Version'),
                  subtitle: Text(_currentVersion.isNotEmpty 
                      ? 'v$_currentVersion' 
                      : 'Loading...'),
                ),
                const Divider(height: 1, thickness: 0.5),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  leading: _checkingUpdate 
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.download_outlined, color: colorScheme.primary),
                  title: const Text('Check for Updates'),
                  enabled: !_checkingUpdate,
                  onTap: _checkForUpdates,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildProviderUsage({
    required String label,
    required int totalTokens,
    required int todayTokens,
    required int budget,
    required double? fraction,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final pct = fraction != null ? (fraction * 100).toInt() : null;
    final barColor = fraction == null
        ? colorScheme.primary
        : fraction < 0.5
            ? const Color(0xFF22C55E) // green
            : fraction < 0.8
                ? const Color(0xFFF59E0B) // amber
                : const Color(0xFFEF4444); // red

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dns, size: 18, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (pct != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: barColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Gradient bar
          SizedBox(
            height: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: fraction != null
                  ? Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              colors: [
                                barColor.withValues(alpha: 0.15),
                                barColor.withValues(alpha: 0.08),
                              ],
                            ),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: fraction,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                colors: [
                                  barColor.withValues(alpha: 0.8),
                                  barColor,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary.withValues(alpha: 0.3),
                            colorScheme.primary.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${TokenSummary.formatTokens(todayTokens)} today',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                budget > 0
                    ? '${TokenSummary.formatTokens(totalTokens)} total · ${TokenSummary.formatTokens(budget)} daily limit'
                    : '${TokenSummary.formatTokens(totalTokens)} total',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const Divider(height: 1, thickness: 0.5),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg + AppSpacing.sm,
        bottom: AppSpacing.xs,
        top: AppSpacing.sm,
      ),
      child: Text(title, style: style),
    );
  }

  PopupMenuItem<AIProvider> _providerPopupItem(AIProvider p) {
    final config = AIConfig.configFor(p)!;
    final hasKey = !config.apiKey.startsWith('YOUR_');
    final isCurrent = p == AIConfig.currentProvider;
    return PopupMenuItem(
      value: p,
      child: Row(
        children: [
          if (isCurrent)
            Icon(Icons.check, color: Colors.green, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              config.label,
              style: TextStyle(
                color: hasKey ? null : Colors.grey,
              ),
            ),
          ),
          Icon(
            hasKey ? Icons.key : Icons.key_off,
            size: 16,
            color: hasKey ? Colors.green : Colors.grey,
          ),
        ],
      ),
    );
  }

  void _switchProvider(AIProvider provider) {
    setState(() {
      AIConfig.currentProvider = provider;
      _aiStatus = 'Not tested';
      _aiStatusDetail = 'Switched to ${AIConfig.activeLabel}';
    });
    AppHaptics.tap();
  }

  Future<void> _testAIConnection() async {
    setState(() {
      _testingAI = true;
      _aiStatus = 'Testing...';
      _aiStatusDetail = '';
    });

    final (success, label, error) = await AIClient.healthCheck();

    setState(() {
      _testingAI = false;
      _aiStatus = success ? 'Connected' : 'Error';
      _aiStatusDetail = success
          ? '$label responding'
          : '$label: ${error!.substring(0, error.length.clamp(0, 60))}';
    });
  }

  Future<void> _testTTS() async {
    setState(() {
      _testingTTS = true;
      _ttsStatus = 'Testing...';
    });

    try {
      final tts = TtsService();
      final result = await tts.speak('Voice test complete');
      setState(() {
        _testingTTS = false;
        _ttsStatus = result.success ? 'Ready' : 'Error: ${result.error}';
      });
      await tts.dispose();
    } catch (e) {
      setState(() {
        _testingTTS = false;
        _ttsStatus = 'Error: $e';
      });
    }
  }

  Future<void> _checkForUpdates() async {
    AppHaptics.tap();
    setState(() => _checkingUpdate = true);
    await showUpdateDialog(context);
    if (mounted) setState(() => _checkingUpdate = false);
  }
}
