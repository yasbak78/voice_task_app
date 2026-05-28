// AI-powered task parser that uses LLMs to parse voice transcriptions.
//
// Wraps the rule-based [TaskParser] with AI capabilities:
// - Sends voice transcripts to LLM via [AIClient]
// - Parses structured JSON into [ParsedTask] objects
// - Falls back to rule-based parser on any error

import 'dart:convert';
import '../config/ai_config.dart';
import '../core/database/app_database.dart';
import '../core/parser/task_parser.dart';
import 'ai_client.dart';

/// JSON-serializable parsed task from LLM response.
class AIParsedTask {
  final String title;
  final String? notes;
  final String? priority; // "high", "medium", "low"
  final String? project;
  final String? dueDate; // ISO 8601 date string
  final String? dueTime; // "HH:mm" format
  final bool hasReminder;
  final int? reminderOffsetMinutes; // positive minutes before due date

  const AIParsedTask({
    required this.title,
    this.notes,
    this.priority,
    this.project,
    this.dueDate,
    this.dueTime,
    this.hasReminder = false,
    this.reminderOffsetMinutes,
  });

  /// Parse from JSON (what the LLM returns).
  factory AIParsedTask.fromJson(Map<String, dynamic> json) {
    final rawTitle = (json['title'] as String?)?.trim();
    return AIParsedTask(
      title: (rawTitle == null || rawTitle.isEmpty) ? 'Untitled Task' : rawTitle,
      notes: (json['notes'] as String?)?.trim(),
      priority: (json['priority'] as String?)?.toLowerCase(),
      project: (json['project'] as String?)?.trim(),
      dueDate: (json['dueDate'] as String?)?.trim(),
      dueTime: (json['dueTime'] as String?)?.trim(),
      hasReminder: json['hasReminder'] == true,
      reminderOffsetMinutes: json['reminderOffsetMinutes'] as int?,
    );
  }

  /// Parse list from JSON array.
  static List<AIParsedTask> listFromJson(List<dynamic> jsonArray) {
    return jsonArray
        .whereType<Map<String, dynamic>>()
        .map((j) => AIParsedTask.fromJson(j))
        .toList();
  }

  /// Convert to the app's [ParsedTask] model.
  ParsedTask toParsedTask() {
    Priority parsedPriority;
    switch (priority?.toLowerCase()) {
      case 'high':
      case 'urgent':
        parsedPriority = Priority.high;
        break;
      case 'low':
        parsedPriority = Priority.low;
        break;
      default:
        parsedPriority = Priority.medium;
    }

    DateTime? parsedDueDate;
    if (dueDate != null && dueDate!.isNotEmpty) {
      try {
        parsedDueDate = DateTime.parse(dueDate!);
      } catch (_) {
        parsedDueDate = null;
      }
    }

    DateTime? parsedDueTime;
    if (dueTime != null && dueTime!.isNotEmpty) {
      try {
        final parts = dueTime!.split(':');
        if (parts.length == 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          parsedDueTime = DateTime(0, 1, 1, hour, minute);
        }
      } catch (_) {
        parsedDueTime = null;
      }
    }

    // Merge dueDate + dueTime
    if (parsedDueDate != null && parsedDueTime != null) {
      parsedDueDate = DateTime(
        parsedDueDate.year,
        parsedDueDate.month,
        parsedDueDate.day,
        parsedDueTime.hour,
        parsedDueTime.minute,
      );
    } else if (parsedDueTime != null) {
      final now = DateTime.now();
      parsedDueDate = DateTime(
        now.year,
        now.month,
        now.day,
        parsedDueTime.hour,
        parsedDueTime.minute,
      );
    }

    final reminderOffset = reminderOffsetMinutes != null
        ? Duration(minutes: reminderOffsetMinutes!)
        : null;

    return ParsedTask(
      title: title,
      notes: notes,
      priority: parsedPriority,
      project: project,
      dueDate: parsedDueDate,
      dueTime: parsedDueTime,
      hasReminder: hasReminder,
      reminderOffset: reminderOffset,
    );
  }

  /// Human-readable summary for debugging.
  String toSummary() {
    final parts = ['"$title"'];
    if (project != null) parts.add('project: $project');
    parts.add('priority: $priority');
    if (dueDate != null) parts.add('due: $dueDate');
    if (hasReminder) parts.add('reminder: ${reminderOffsetMinutes}min before');
    return parts.join(', ');
  }
}

/// AI-powered task parser service.
///
/// Usage:
/// ```dart
/// final parser = AITaskParser();
/// final result = await parser.parse('remind me to buy milk tomorrow at 9am');
/// ```
class AITaskParser {
  /// Parse a single voice transcription using AI with fallback.
  ///
  /// Tries the LLM first. On any error (network/timeout/parse),
  /// falls back to the rule-based [TaskParser.parse].
  static Future<ParsedTask> parse(String transcription) async {
    try {
      final aiTasks = await _parseWithAI(transcription);
      if (aiTasks.isNotEmpty) {
        return aiTasks.first.toParsedTask();
      }
    } catch (e) {
      // Log error for debugging but don't crash
      // print('[AITaskParser] AI parse failed: $e, falling back');
    }

    // Fallback to rule-based parser
    return TaskParser.parse(transcription);
  }

  /// Parse multi-intent voice input using AI with fallback.
  ///
  /// Returns [ParserResult] with multiple tasks or conversational reply.
  static Future<ParserResult> splitAndParse(String transcription) async {
    try {
      final aiTasks = await _parseWithAI(transcription);
      if (aiTasks.isNotEmpty) {
        return ParserResult(
          tasks: aiTasks.map((t) => t.toParsedTask()).toList(),
        );
      }
    } catch (e) {
      // print('[AITaskParser] AI splitAndParse failed: $e, falling back');
    }

    // Fallback to rule-based parser
    return TaskParser.splitAndParse(transcription);
  }

  /// Internal: send transcription to LLM and parse JSON response.
  static Future<List<AIParsedTask>> _parseWithAI(String transcription) async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

    final prompt = 'Parse voice input into tasks. Return JSON array only.\n'
        'Each task: title(str), priority("high"|"medium"|"low"), hasReminder(bool)\n'
        'Optional: notes, project, dueDate(ISO), dueTime("HH:mm"), reminderOffsetMinutes(int)\n'
        'No tasks/conversational → []. "tomorrow"=$tomorrowStr "today"=$today\n'
        'Reminders ("remind me X min before","set a reminder") → hasReminder=true + reminderOffsetMinutes in parent task, NEVER a separate task.\n'
        '"and also remind me"/"and set reminder" → attach to preceding task. Only "and"+new action → new task.\n'
        'Example: "remind me to buy milk tomorrow at 9am"→[{"title":"Buy milk","priority":"medium","dueDate":"$tomorrowStr","dueTime":"09:00","hasReminder":true,"reminderOffsetMinutes":15}]\n'
        'Example: "urgent call dentist today"→[{"title":"Call dentist","priority":"high","dueDate":"$today","hasReminder":false}]\n'
        'VOICE: "$transcription"\nJSON:';

    final response = await AIClient.chat(
      messages: [
        {'role': 'system', 'content': 'JSON-only task parser. Return only JSON arrays.'},
        {'role': 'user', 'content': prompt},
      ],
      temperature: 0.0,
      maxTokens: AIConfig.maxParseTokens,
      purpose: 'task_parse',
      jsonMode: true,
    );

    return _parseJsonResponse(response);
  }

  /// Parse LLM response text into [AIParsedTask] list.
  static List<AIParsedTask> _parseJsonResponse(String response) {
    // Extract JSON from possible markdown code blocks
    String cleaned = response.trim();

    // Remove markdown code blocks if present
    if (cleaned.startsWith('```')) {
      final lines = cleaned.split('\n');
      lines.removeWhere((l) => l.startsWith('```'));
      cleaned = lines.join('\n').trim();
    }

    // Find first [ and last ]
    final openBracket = cleaned.indexOf('[');
    final closeBracket = cleaned.lastIndexOf(']');

    if (openBracket == -1 || closeBracket == -1) {
      throw FormatException('No JSON array found in response');
    }

    final jsonStr = cleaned.substring(openBracket, closeBracket + 1);
    final parsed = jsonDecode(jsonStr) as List;

    if (parsed.isEmpty) {
      return [];
    }

    return AIParsedTask.listFromJson(parsed);
  }
}
