import 'package:flutter/material.dart';
import '../../core/haptics/app_haptics.dart';
import '../../core/database/app_database.dart';
import '../../services/scheduling_service.dart';
import '../../services/nl_query_service.dart';
import '../../services/tts_service.dart';

class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  List<SchedulingSuggestion> _suggestions = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<int> _acceptedSuggestions = {};
  final Set<int> _declinedSuggestions = {};

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = AppDatabase();
      final service = NLQueryService(db);
      final result = await service.execute('show all tasks');

      final suggestions = await SchedulingService.analyzeAndSuggest(
        tasks: result.tasks,
      );

      await db.close();

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to analyze schedule: $e';
        });
      }
    }
  }

  Future<void> _acceptSuggestion(int index) async {
    AppHaptics.complete();

    final suggestion = _suggestions[index];

    // Execute actions against the database if any exist
    if (suggestion.actions.isNotEmpty) {
      try {
        final db = AppDatabase();
        final results = await SchedulingService.executeSuggestionActions(
          db: db,
          actions: suggestion.actions,
        );
        await db.close();

        final successCount = results.where((r) => r.success).length;
        final failCount = results.length - successCount;

        if (!mounted) return;

        if (failCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$successCount of ${results.length} actions applied. '
                '${failCount > 1 ? '$failCount failed' : '1 failed'}.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply suggestion: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return; // Don't mark as accepted if execution failed
      }
    }

    setState(() => _acceptedSuggestions.add(index));

    // Voice confirmation
    ttsService.speak(
      'Done. ${suggestion.title}. ${suggestion.description}',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Suggestion applied: ${_suggestions[index].title}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _declineSuggestion(int index) {
    AppHaptics.tap();
    setState(() => _declinedSuggestions.add(index));
  }

  IconData _typeIcon(SuggestionType type) {
    switch (type) {
      case SuggestionType.spreadLoad:
        return Icons.balance_outlined;
      case SuggestionType.consolidate:
        return Icons.merge_type_outlined;
      case SuggestionType.deadline:
        return Icons.flag_outlined;
      case SuggestionType.freeSlot:
        return Icons.event_available_outlined;
      case SuggestionType.overdue:
        return Icons.warning_amber_outlined;
      case SuggestionType.capacity:
        return Icons.add_circle_outline;
    }
  }

  Color _typeColor(SuggestionType type) {
    switch (type) {
      case SuggestionType.spreadLoad:
        return const Color(0xFF42A5F5);
      case SuggestionType.consolidate:
        return const Color(0xFFAB47BC);
      case SuggestionType.deadline:
        return const Color(0xFFEF4444);
      case SuggestionType.freeSlot:
        return const Color(0xFF22C55E);
      case SuggestionType.overdue:
        return const Color(0xFFE53935);
      case SuggestionType.capacity:
        return const Color(0xFF66BB6A);
    }
  }

  String _typeLabel(SuggestionType type) {
    switch (type) {
      case SuggestionType.spreadLoad:
        return 'Spread Load';
      case SuggestionType.consolidate:
        return 'Consolidate';
      case SuggestionType.deadline:
        return 'Deadline';
      case SuggestionType.freeSlot:
        return 'Free Slot';
      case SuggestionType.overdue:
        return 'Overdue';
      case SuggestionType.capacity:
        return 'Capacity';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduling Suggestions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSuggestions,
            tooltip: 'Refresh suggestions',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSuggestions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _suggestions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: cs.tertiary,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your schedule looks great!',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No scheduling suggestions at this time.',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSuggestions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          return _buildSuggestionCard(index, _suggestions[index]);
                        },
                      ),
                    ),
    );
  }

  Widget _buildSuggestionCard(int index, SchedulingSuggestion suggestion) {
    final isAccepted = _acceptedSuggestions.contains(index);
    final isDeclined = _declinedSuggestions.contains(index);
    final cs = Theme.of(context).colorScheme;

    if (isDeclined) {
      return const SizedBox.shrink();
    }

    final accentColor = _typeColor(suggestion.type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isAccepted
            ? accentColor.withValues(alpha: 0.08)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAccepted ? accentColor : cs.outline.withValues(alpha: 0.3),
          width: isAccepted ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_typeIcon(suggestion.type), color: accentColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              suggestion.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (suggestion.confidence >= 80)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${suggestion.confidence}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        _typeLabel(suggestion.type),
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              suggestion.description,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (suggestion.reasoning.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: accentColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suggestion.reasoning,
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (suggestion.actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestion.actions.take(3).map((action) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      action.actionLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            if (!isAccepted)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _declineSuggestion(index),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Dismiss'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant,
                        side: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _acceptSuggestion(index),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Apply'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Applied',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
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
