import 'dart:convert';
import '../config/ai_config.dart';
import '../core/database/app_database.dart';
import '../services/ai_client.dart';

/// A scheduling suggestion with accept/decline semantics.
class SchedulingSuggestion {
  final String title;
  final String description;
  final SuggestionType type;
  final List<TaskSuggestionAction> actions;
  final String reasoning;
  final int confidence; // 0-100

  const SchedulingSuggestion({
    required this.title,
    required this.description,
    required this.type,
    required this.actions,
    required this.reasoning,
    this.confidence = 75,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'type': type.name,
        'actions': actions.map((a) => a.toJson()).toList(),
        'reasoning': reasoning,
        'confidence': confidence,
      };
}

enum SuggestionType {
  spreadLoad,    // "You have 5 tasks Monday — spread to Tuesday/Wednesday?"
  consolidate,   // "2 short tasks at 3pm — batch them together?"
  deadline,      // "High priority task due tomorrow — prioritize it now?"
  freeSlot,      // "You have a free slot at 2pm — good for 'read report'"
  overdue,       // "3 overdue tasks — reschedule or complete?"
  capacity,      // "Only 1 task Thursday — room for more?"
}

/// An action the user can take on a suggestion.
class TaskSuggestionAction {
  final String taskId;
  final DateTime? newDueDate;
  final String? newTimeSlot;
  final String actionLabel; // "Move to Tuesday", "Batch together", etc.

  const TaskSuggestionAction({
    required this.taskId,
    this.newDueDate,
    this.newTimeSlot,
    required this.actionLabel,
  });

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'newDueDate': newDueDate?.toIso8601String(),
        'newTimeSlot': newTimeSlot,
        'actionLabel': actionLabel,
      };
}

/// Analyzes task list and generates smart scheduling suggestions.
class SchedulingService {
  /// Generate scheduling suggestions based on task density analysis.
  /// Returns a list of actionable suggestions (may be empty if schedule is optimal).
  static Future<List<SchedulingSuggestion>> analyzeAndSuggest({
    required List<Task> tasks,
  }) async {
    final pendingTasks = tasks.where((t) => t.status != TaskStatus.done).toList();
    if (pendingTasks.isEmpty) {
      return [];
    }

    // Try AI analysis first
    try {
      final suggestions = await _generateAISuggestions(pendingTasks);
      if (suggestions.isNotEmpty) {
        return suggestions;
      }
    } catch (_) {
      // Fall through to rule-based analysis
    }

    // Rule-based fallback
    return _generateRuleBasedSuggestions(pendingTasks);
  }

  /// AI-powered scheduling analysis.
  static Future<List<SchedulingSuggestion>> _generateAISuggestions(
    List<Task> pendingTasks,
  ) async {
    final taskSummary = pendingTasks.map((t) {
      final due = t.dueDate != null
          ? '${t.dueDate!.year}-${t.dueDate!.month.toString().padLeft(2, '0')}-${t.dueDate!.day.toString().padLeft(2, '0')}'
          : 'no date';
      final time = t.dueDate != null && t.dueDate!.hour != 0
          ? '${t.dueDate!.hour}:${t.dueDate!.minute.toString().padLeft(2, '0')}'
          : 'no time';
      return '- [${t.priority.name}] "${t.title}" | due: $due $time | project: ${t.project ?? "none"}';
    }).join('\n');

    final now = DateTime.now();
    final prompt = 'Analyze tasks and suggest scheduling optimizations. Return JSON array (max 5).\n'
        'Types: spreadLoad|consolidate|deadline|freeSlot|overdue|capacity\n'
        'Each: {title(str), description(str), type, actions:[{taskId(str), actionLabel(str)}], reasoning(str), confidence(0-100)}\n'
        'Look for: 3+ tasks/day (spread), high-priority w/o date (deadline), free days (freeSlot), overdue (overdue), similar tasks (consolidate)\n'
        'Today: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}\n'
        'Tasks:\n$taskSummary\nJSON:';

    final response = await AIClient.chat(
      messages: [
        {'role': 'system', 'content': 'JSON-only scheduling assistant.'},
        {'role': 'user', 'content': prompt},
      ],
      temperature: 0.0,
      maxTokens: AIConfig.maxSchedulingTokens,
      purpose: 'scheduling',
      jsonMode: true,
    );

    return _parseSuggestionResponse(response);
  }

  /// Parse AI response into suggestions.
  static List<SchedulingSuggestion> _parseSuggestionResponse(String response) {
    try {
      String jsonStr = response.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
      }

      final List<dynamic> data = jsonDecode(jsonStr);
      return data.map((item) {
        final map = item as Map<String, dynamic>;
        final actions = (map['actions'] as List<dynamic>?)
                ?.map((a) {
                  final m = a as Map<String, dynamic>;
                  return TaskSuggestionAction(
                    taskId: m['taskId']?.toString() ?? '',
                    actionLabel: m['actionLabel']?.toString() ?? 'Apply',
                  );
                })
                .toList() ??
            [];

        SuggestionType type;
        try {
          type = SuggestionType.values
              .firstWhere((t) => t.name == map['type']);
        } catch (_) {
          type = SuggestionType.spreadLoad;
        }

        return SchedulingSuggestion(
          title: map['title']?.toString() ?? 'Scheduling suggestion',
          description: map['description']?.toString() ?? '',
          type: type,
          actions: actions,
          reasoning: map['reasoning']?.toString() ?? '',
          confidence: (map['confidence'] as num?)?.toInt() ?? 75,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Rule-based scheduling analysis (fallback when AI is unavailable).
  static List<SchedulingSuggestion> _generateRuleBasedSuggestions(
    List<Task> pendingTasks,
  ) {
    final suggestions = <SchedulingSuggestion>[];
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    // Group tasks by date
    final tasksByDate = <String, List<Task>>{};
    final undatedTasks = <Task>[];

    for (final task in pendingTasks) {
      if (task.dueDate != null) {
        final key =
            '${task.dueDate!.year}-${task.dueDate!.month.toString().padLeft(2, '0')}-${task.dueDate!.day.toString().padLeft(2, '0')}';
        tasksByDate.putIfAbsent(key, () => []).add(task);
      } else {
        undatedTasks.add(task);
      }
    }

    // 1. Overload detection: days with 3+ tasks
    for (final entry in tasksByDate.entries) {
      if (entry.value.length >= 3) {
        final highPri = entry.value.where((t) => t.priority == Priority.high);
        suggestions.add(SchedulingSuggestion(
          title: 'Heavy day detected',
          description:
              'You have ${entry.value.length} tasks on ${entry.key}. Consider moving some to adjacent days.',
          type: SuggestionType.spreadLoad,
          actions: entry.value.map((t) => TaskSuggestionAction(
                taskId: t.id,
                actionLabel: 'Move "${t.title}" to another day',
              )).toList(),
          reasoning:
              '${entry.value.length} tasks in one day may cause overload. ${highPri.length} are high priority.',
          confidence: 80,
        ));
      }
    }

    // 2. Undated high-priority tasks
    final highPriUndated = undatedTasks.where((t) => t.priority == Priority.high).toList();
    if (highPriUndated.isNotEmpty) {
      suggestions.add(SchedulingSuggestion(
        title: 'High priority tasks need deadlines',
        description:
            '${highPriUndated.length} high-priority task(s) have no due date. Set a deadline to stay on track.',
        type: SuggestionType.deadline,
        actions: highPriUndated.map((t) => TaskSuggestionAction(
              taskId: t.id,
              actionLabel: 'Set deadline for "${t.title}"',
            )).toList(),
        reasoning: 'High priority tasks without dates risk being forgotten.',
        confidence: 90,
      ));
    }

    // 3. Overdue tasks
    final overdue = pendingTasks.where((t) {
      if (t.dueDate == null) return false;
      final dueDay = DateTime(
        t.dueDate!.year,
        t.dueDate!.month,
        t.dueDate!.day,
      );
      return dueDay.isBefore(startOfDay);
    }).toList();

    if (overdue.isNotEmpty) {
      suggestions.add(SchedulingSuggestion(
        title: 'Overdue tasks',
        description:
            '${overdue.length} task(s) are past their due date. Reschedule or complete them.',
        type: SuggestionType.overdue,
        actions: overdue.map((t) => TaskSuggestionAction(
              taskId: t.id,
              actionLabel: 'Reschedule "${t.title}"',
            )).toList(),
        reasoning: 'Overdue tasks accumulate stress — address them first.',
        confidence: 95,
      ));
    }

    // 4. Free day detection (look ahead 7 days)
    for (int i = 1; i <= 7; i++) {
      final checkDate = startOfDay.add(Duration(days: i));
      final key =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      final count = tasksByDate[key]?.length ?? 0;
      if (count == 0 && undatedTasks.isNotEmpty) {
        suggestions.add(SchedulingSuggestion(
          title: 'Free day available',
          description:
              '${_formatDate(checkDate)} has no tasks. Good day to schedule "${undatedTasks.first.title}".',
          type: SuggestionType.freeSlot,
          actions: [
            TaskSuggestionAction(
              taskId: undatedTasks.first.id,
              newDueDate: checkDate,
              actionLabel: 'Move to ${_formatDate(checkDate)}',
            ),
          ],
          reasoning: 'Spreading tasks across available days prevents overload.',
          confidence: 60,
        ));
        break; // Only suggest one free day
      }
    }

    // Sort by confidence (highest first)
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return suggestions.take(5).toList();
  }

  static String _formatDate(DateTime date) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[date.weekday % 7]} ${months[date.month - 1]} ${date.day}';
  }

  /// Execute all actions for an accepted suggestion against the database.
  /// Returns a list of results (success/failure per action).
  static Future<List<ActionExecutionResult>> executeSuggestionActions({
    required AppDatabase db,
    required List<TaskSuggestionAction> actions,
  }) async {
    final results = <ActionExecutionResult>[];

    for (final action in actions) {
      try {
        final task = await db.taskDao.getTaskById(action.taskId);
        if (task == null) {
          results.add(ActionExecutionResult(
            actionLabel: action.actionLabel,
            success: false,
            error: 'Task not found: ${action.taskId}',
          ));
          continue;
        }

        // Build updated task by copying original and applying changes
        DateTime? newDueDate = task.dueDate;
        TaskStatus? newStatus;

        // Apply new due date if provided
        if (action.newDueDate != null) {
          // Preserve original time if task had one, otherwise use morning (9am)
          final targetDate = action.newDueDate!;
          if (task.dueDate != null && task.dueDate!.hour != 0) {
            newDueDate = DateTime(
              targetDate.year,
              targetDate.month,
              targetDate.day,
              task.dueDate!.hour,
              task.dueDate!.minute,
            );
          } else {
            newDueDate = DateTime(
              targetDate.year,
              targetDate.month,
              targetDate.day,
              9, 0, // Default to 9am for tasks without a time
            );
          }
        }

        // Apply time slot if provided (parse "HH:MM" format)
        if (action.newTimeSlot != null) {
          final parts = action.newTimeSlot!.split(':');
          if (parts.length == 2) {
            final hour = int.tryParse(parts[0]) ?? 9;
            final minute = int.tryParse(parts[1]) ?? 0;
            final baseDate = newDueDate ?? task.dueDate ?? DateTime.now();
            newDueDate = DateTime(
              baseDate.year,
              baseDate.month,
              baseDate.day,
              hour,
              minute,
            );
          }
        }

        // Detect "mark complete" actions by label
        final labelLower = action.actionLabel.toLowerCase();
        if (labelLower.contains('complete') || labelLower.contains('mark done')) {
          newStatus = TaskStatus.done;
        }

        // Build updated task
        final updatedTask = Task(
          id: task.id,
          title: task.title,
          notes: task.notes,
          dueDate: newDueDate,
          priority: task.priority,
          project: task.project,
          status: newStatus ?? task.status,
          createdAt: task.createdAt,
          completedAt: newStatus == TaskStatus.done ? DateTime.now() : task.completedAt,
          hasReminder: task.hasReminder,
          reminderTime: task.reminderTime,
          reminderSound: task.reminderSound,
          isCalendarEvent: task.isCalendarEvent,
        );

        await db.taskDao.updateTask(updatedTask);
        results.add(ActionExecutionResult(
          actionLabel: action.actionLabel,
          success: true,
          taskId: task.id,
          taskTitle: task.title,
        ));
      } catch (e) {
        results.add(ActionExecutionResult(
          actionLabel: action.actionLabel,
          success: false,
          error: e.toString(),
        ));
      }
    }

    return results;
  }
}

/// Result of executing a single suggestion action.
class ActionExecutionResult {
  final String actionLabel;
  final bool success;
  final String? taskId;
  final String? taskTitle;
  final String? error;

  const ActionExecutionResult({
    required this.actionLabel,
    required this.success,
    this.taskId,
    this.taskTitle,
    this.error,
  });
}
