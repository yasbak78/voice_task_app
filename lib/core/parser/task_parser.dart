import 'package:intl/intl.dart';

/// Parsed task result from voice input.
class ParsedTask {
  final String title;
  final String? notes;
  final Priority priority;
  final String? project;
  final DateTime? dueDate;
  final DateTime? dueTime;
  final bool hasReminder;

  const ParsedTask({
    required this.title,
    this.notes,
    this.priority = Priority.medium,
    this.project,
    this.dueDate,
    this.dueTime,
    this.hasReminder = false,
  });

  ParsedTask copyWith({
    String? title,
    String? notes,
    Priority? priority,
    String? project,
    DateTime? dueDate,
    DateTime? dueTime,
    bool? hasReminder,
  }) {
    return ParsedTask(
      title: title ?? this.title,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      project: project ?? this.project,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      hasReminder: hasReminder ?? this.hasReminder,
    );
  }
}

/// Result of splitting multi-intent voice input.
class ParserResult {
  final List<ParsedTask> tasks;
  final String? conversationalReply;

  const ParserResult({
    required this.tasks,
    this.conversationalReply,
  });

  bool get isConversational =>
      tasks.isEmpty && conversationalReply != null;

  bool get hasTasks => tasks.isNotEmpty;
}

/// Priority level for tasks.
enum Priority { high, medium, low }

/// Main task parser — converts voice transcriptions into structured tasks.
class TaskParser {
  // Priority keywords
  static final _highPriority = RegExp(
    r'\b(high\s*pri(ority)?|urgent|asap|critical|emergency|immediately|right now|must do|important)\b',
    caseSensitive: false,
  );

  static final _lowPriority = RegExp(
    r'\b(low\s*pri(ority)?|whenever|eventually|someday|nice to have|no rush)\b',
    caseSensitive: false,
  );

  // Project keywords
  static final _projectPattern = RegExp(
    r'(?:for|on|in|under|from)\s+(?:the\s+)?(?:project\s+)?(\w[\w\s]*?(?:project|app|site|team|client|course|work|home|school|personal|gym|health|finance|kitchen|garden))\b',
    caseSensitive: false,
  );

  static final _projectPrefix = RegExp(
    r'^\s*(?:project|proj|for|under)\s*[:\-]\s*',
    caseSensitive: false,
  );

  // Reminder keywords
  static final _reminderPattern = RegExp(
    r'\b(remind\s*me|set\s*(?:a\s*)?reminder|alarm|notify\s*me|alert\s*me)\b',
    caseSensitive: false,
  );

  // Filler words to strip
  static final _fillerPattern = RegExp(
    r'^(um\s*|uh\s*|so\s*|like\s*|hey\s*|hi\s*|hello\s*|okay\s*|ok\s*|alright\s*|can\s*you\s*|please\s*|I\s*need\s*to\s*|I\s*want\s*to\s*|I\s*wanna\s*|wanna\s*|I\s*should\s*|let\s*me\s*|gonna\s*|gotta\s*|just\s*)+',
    caseSensitive: false,
  );

  // Time patterns
  static final _timePattern = RegExp(
    r'\b(at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)\b',
    caseSensitive: false,
  );

  // Relative date patterns
  static const Map<String, int> _fixedDayOffsets = {
    'today': 0,
    'tomorrow': 1,
    'next week': 7,
    'in a week': 7,
    'in two weeks': 14,
    'in a month': 30,
    'next month': 30,
    'yesterday': -1,
    'last week': -7,
    'in a few days': 3,
    'in three days': 3,
    'this weekend': 5,
  };

  static const Map<String, int> _dayOfWeekOffsets = {
    'on monday': 1,
    'on tuesday': 2,
    'on wednesday': 3,
    'on thursday': 4,
    'on friday': 5,
    'on saturday': 6,
    'on sunday': 0,
  };

  static const Map<String, int> _nextDayOfWeekOffsets = {
    'next monday': 1,
    'next tuesday': 2,
    'next wednesday': 3,
    'next thursday': 4,
    'next friday': 5,
    'next saturday': 6,
    'next sunday': 0,
  };

  static int _dayOffsetFromNow(int targetWeekday) {
    final now = DateTime.now();
    int diff = targetWeekday - (now.weekday % 7);
    if (diff <= 0) diff += 7;
    return diff;
  }

  static int _nextDayOffsetFromNow(int targetWeekday) {
    return _dayOffsetFromNow(targetWeekday) + 7;
  }

  /// Parse a single voice transcription into a structured task.
  static ParsedTask parse(String input) {
    var text = input.trim();

    // Strip filler words
    text = text.replaceFirst(_fillerPattern, '').trim();

    // Extract priority
    final priority = _extractPriority(text);
    text = text.replaceFirst(_highPriority, '').trim();
    text = text.replaceFirst(_lowPriority, '').trim();

    // Extract project
    String? project = _extractProject(text);
    text = text.replaceAll(_projectPattern, '').trim();
    text = text.replaceAll(_projectPrefix, '').trim();

    // Extract reminder flag
    final hasReminder = _reminderPattern.hasMatch(text);
    text = text.replaceAll(_reminderPattern, '').trim();

    // Extract time
    DateTime? dueTime;
    final timeMatch = _timePattern.firstMatch(text);
    if (timeMatch != null) {
      dueTime = _parseTime(timeMatch);
      text = text.replaceFirst(_timePattern, '').trim();
    }

    // Extract due date
    DateTime? dueDate = _extractDueDate(text);
    if (dueDate != null && dueTime != null) {
      dueDate = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        dueTime.hour,
        dueTime.minute,
      );
    } else if (dueTime != null) {
      // Time without date -> today + time
      final now = DateTime.now();
      dueDate = DateTime(now.year, now.month, now.day, dueTime.hour, dueTime.minute);
    }

    // Clean up remaining text for title
    text = _cleanTitle(text);

    // Split into title and notes if too long
    String title;
    String? notes;
    if (text.length > 40) {
      final firstSentence = _splitAtSentence(text);
      title = firstSentence;
      final remainder = text.substring(firstSentence.length).trim();
      notes = remainder.isNotEmpty ? remainder : null;
    } else {
      title = text;
    }

    // Fallback title
    if (title.isEmpty) {
      title = input.trim().length > 40
          ? '${input.trim().substring(0, 40)}...'
          : input.trim();
    }

    return ParsedTask(
      title: title,
      notes: notes,
      priority: priority,
      project: project,
      dueDate: dueDate,
      hasReminder: hasReminder,
    );
  }

  /// Split multi-intent input into separate task candidates.
  static ParserResult splitAndParse(String input) {
    final lower = input.toLowerCase().trim();

    // Check if this is conversational (not a task)
    if (_isConversational(lower)) {
      return ParserResult(
        tasks: [],
        conversationalReply: _getConversationalReply(lower),
      );
    }

    // Split on intent boundaries
    final segments = _splitIntents(input);

    final tasks = segments
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 2)
        .map((s) => parse(s))
        .toList();

    return ParserResult(tasks: tasks);
  }

  static Priority _extractPriority(String text) {
    if (_highPriority.hasMatch(text)) return Priority.high;
    if (_lowPriority.hasMatch(text)) return Priority.low;
    return Priority.medium;
  }

  static String? _extractProject(String text) {
    // Try project pattern first
    final match = _projectPattern.firstMatch(text);
    if (match != null) {
      return match.group(1)?.trim();
    }

    // Try #project format
    final hashMatch = RegExp(r'#(\w[\w-]*)').firstMatch(text);
    if (hashMatch != null) {
      return hashMatch.group(1)?.trim();
    }

    return null;
  }

  static DateTime? _extractDueDate(String text) {
    final lower = text.toLowerCase();

    // Check fixed day offsets
    for (final entry in _fixedDayOffsets.entries) {
      if (lower.contains(entry.key)) {
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day + entry.value);
      }
    }

    // Check day-of-week offsets
    for (final entry in _dayOfWeekOffsets.entries) {
      if (lower.contains(entry.key)) {
        final offset = _dayOffsetFromNow(entry.value);
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day + offset);
      }
    }

    // Check next day-of-week offsets
    for (final entry in _nextDayOfWeekOffsets.entries) {
      if (lower.contains(entry.key)) {
        final offset = _nextDayOffsetFromNow(entry.value);
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day + offset);
      }
    }

    // Try parsing explicit date patterns (e.g., "Jan 15", "15/03/2025")
    final explicitPatterns = [
      RegExp(r'(?:on\s+)?(\w+ \d{1,2})(?:st|nd|rd|th)?\b'),
      RegExp(r'(\d{1,2}[/\-]\d{1,2}(?:[/\-]\d{2,4})?)'),
    ];

    for (final pattern in explicitPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          final formats = [
            DateFormat('MMMM d'),
            DateFormat('MMM d'),
            DateFormat('d/M/yyyy'),
            DateFormat('d/M/yy'),
            DateFormat('M/d/yyyy'),
            DateFormat('M/d/yy'),
          ];
          for (final fmt in formats) {
            try {
              final parsed = fmt.parseStrict(match.group(1)!);
              return DateTime(parsed.year, parsed.month, parsed.day);
            } catch (_) {
              continue;
            }
          }
        } catch (_) {
          continue;
        }
      }
    }

    return null;
  }

  static DateTime? _parseTime(RegExpMatch match) {
    try {
      final hour = int.parse(match.group(2)!);
      final minute = int.tryParse(match.group(3) ?? '0') ?? 0;
      final period = match.group(4)?.toLowerCase();

      int adjustedHour = hour;
      if (period != null) {
        if (period.startsWith('p') && hour != 12) {
          adjustedHour += 12;
        } else if (period.startsWith('a') && hour == 12) {
          adjustedHour = 0;
        }
      }

      return DateTime(0, 0, 0, adjustedHour, minute);
    } catch (_) {
      return null;
    }
  }

  static String _cleanTitle(String text) {
    // Remove trailing filler
    final trailingFiller = RegExp(r'\s+(please|thanks|thank you|ok|okay|yeah)\s*\.?$', caseSensitive: false);
    text = text.replaceFirst(trailingFiller, '').trim();

    // Capitalize first letter
    if (text.isNotEmpty) {
      text = text[0].toUpperCase() + text.substring(1);
    }

    // Remove trailing punctuation
    text = text.replaceAll(RegExp(r'[.!?]+$'), '').trim();

    return text;
  }

  static String _splitAtSentence(String text) {
    // Try to split at first sentence boundary
    final match = RegExp(r'^[^.!?]*[.!?]').firstMatch(text);
    if (match != null && match.group(0)!.length >= 10) {
      return match.group(0)!.trim();
    }
    // Otherwise split at ~40 chars at word boundary
    if (text.length > 40) {
      int splitAt = 40;
      while (splitAt > 20 && text[splitAt] != ' ') {
        splitAt--;
      }
      return text.substring(0, splitAt).trim();
    }
    return text;
  }

  static List<String> _splitIntents(String input) {
    // Use allMatches to find split positions
    final splitRegex = RegExp(
      r'(?:^|[.!?;]+)\s*(?:and\s+|also\s+|then\s+|plus\s+|next\s+|oh\s*[,!]*\s*|wait\s*[,!]*\s*)+',
      caseSensitive: false,
    );
    final matches = splitRegex.allMatches(input);

    if (matches.isEmpty) {
      // Try splitting on "and" between task-like phrases
      final andRegex = RegExp(r'\s+and\s+(?:also\s+)?', caseSensitive: false);
      final andMatches = andRegex.allMatches(input);
      if (andMatches.isNotEmpty) {
        final segments = <String>[];
        int lastEnd = 0;
        for (final m in andMatches) {
          final segment = input.substring(lastEnd, m.start).trim();
          if (segment.isNotEmpty && segment.length > 5) {
            segments.add(segment);
          }
          lastEnd = m.end;
        }
        final remainder = input.substring(lastEnd).trim();
        if (remainder.isNotEmpty && remainder.length > 5) {
          segments.add(remainder);
        }
        if (segments.length > 1) return segments;
      }
      return [input];
    }

    final segments = <String>[];
    int lastEnd = 0;
    for (final m in matches) {
      final segment = input.substring(lastEnd, m.start).trim();
      if (segment.isNotEmpty) {
        segments.add(segment);
      }
      lastEnd = m.end;
    }
    final remainder = input.substring(lastEnd).trim();
    if (remainder.isNotEmpty) {
      segments.add(remainder);
    }

    return segments;
  }

  static bool _isConversational(String text) {
    // Strip common punctuation for matching
    final cleaned = text.replaceAll(RegExp(r'[?!,.]'), '').trim();
    final conversationalPatterns = RegExp(
      r"^(how are you|hey how are you|what'?s up|hi there|hey there|good morning|good evening|"
      r"good night|hey how is it going|how'?s it going|see you later|talk to you|"
      r"thanks for asking|nice to meet you|i am fine|i am good|im good|"
      r"thank you|thank you so much|thanks|thanks a lot|hey|hello)$",
      caseSensitive: false,
    );
    return conversationalPatterns.hasMatch(cleaned) &&
        !RegExp(r"\b(task|do|finish|remind|call|email|schedule|meeting|"
                r"deadline|submit|buy|create|send|book|write|review|fix)\b",
          caseSensitive: false,
        )
            .hasMatch(text);
  }

  static String? _getConversationalReply(String text) {
    if (text.contains('how are you') || text.contains('?s up')) {
      return "I'm doing great! Ready to help with your tasks.";
    }
    if (text.contains('good morning')) {
      return 'Good morning! What tasks can I help with today?';
    }
    if (text.contains('good evening') || text.contains('good night')) {
      return 'Good evening! Anything you need to capture before wrapping up?';
    }
    if (RegExp(r'(thanks|thank you)', caseSensitive: false).hasMatch(text)) {
      return "You're welcome! Let me know if you need anything.";
    }
    return null;
  }
}
