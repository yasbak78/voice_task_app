import 'dart:convert';
import '../core/database/app_database.dart';
import 'ai_client.dart';

/// Structured query extracted from natural language by AI.
///
/// The AI classifies the user's intent and extracts parameters, then this
/// service maps the query to Drift DAO calls and returns matching tasks.
class NLQuery {
  final NLQueryType type;
  final String? keyword;       // for keyword search
  final String? statusFilter;  // 'pending', 'done', 'all'
  final String? project;       // filter by project name
  final String? priorityFilter; // 'high', 'medium', 'low'
  final DateRange? dateRange;  // date-based filter
  final bool aggregate;        // if true, return count/summary instead of tasks
  final String rawQuestion;

  NLQuery({
    required this.type,
    this.keyword,
    this.statusFilter,
    this.project,
    this.priorityFilter,
    this.dateRange,
    this.aggregate = false,
    required this.rawQuestion,
  });
}

enum NLQueryType {
  filterByStatus,
  filterByKeyword,
  filterByDate,
  filterByProject,
  filterByPriority,
  aggregate,
  listAll,
  conversational,
}

enum DateRange { today, thisWeek, thisMonth, overdue, upcoming }

/// Result of executing a natural language query.
class NLQueryResult {
  final List<Task> tasks;
  final String summary;
  final int totalCount;
  final bool isConversational;
  final String? conversationalReply; // AI-generated text response (no tasks)

  NLQueryResult({
    this.tasks = const [],
    required this.summary,
    required this.totalCount,
    this.isConversational = false,
    this.conversationalReply,
  });
}

/// Service that converts natural language questions into database queries.
///
/// Pipeline:
/// 1. AI extracts query parameters from the user's question
/// 2. Service executes the appropriate Drift query
/// 3. AI formats the results as a natural language summary
class NLQueryService {
  final AppDatabase db;

  NLQueryService(this.db);

  /// Execute a natural language query against the task database.
  Future<NLQueryResult> execute(String question) async {
    // Step 1: AI extracts structured query from natural language
    final nlQuery = await _extractQuery(question);

    // Handle purely conversational queries (no task data needed)
    if (nlQuery.type == NLQueryType.conversational) {
      final reply = await _conversationalReply(question);
      return NLQueryResult(
        summary: reply,
        totalCount: 0,
        isConversational: true,
        conversationalReply: reply,
      );
    }

    // Step 2: Execute the appropriate Drift query
    final tasks = await _runQuery(nlQuery);

    // Step 3: AI formats results as natural language
    final summary = await _formatResults(nlQuery, tasks);

    return NLQueryResult(
      tasks: tasks,
      summary: summary,
      totalCount: tasks.length,
    );
  }

  /// Use AI to extract structured query parameters from natural language.
  Future<NLQuery> _extractQuery(String question) async {
    final prompt = '''You are a query parser for a task management app. Convert the user's question into a structured query.

The app has tasks with these fields: title, notes, priority (high/medium/low), project, status (pending/inProgress/done/archived), dueDate, createdAt.

Return ONLY a JSON object with these fields (omit fields that are null):
- "type": one of: "filterByStatus", "filterByKeyword", "filterByDate", "filterByProject", "filterByPriority", "aggregate", "listAll", "conversational"
- "keyword": string — search term for title/notes (if applicable)
- "statusFilter": "pending", "done", "inProgress", "archived", or "all"
- "project": project name (if mentioned)
- "priorityFilter": "high", "medium", "low"
- "dateRange": "today", "thisWeek", "thisMonth", "overdue", "upcoming" (if applicable)
- "aggregate": true if asking for a count/summary, false if asking for a list

Examples:
- "show me overdue tasks about Nallini" → {"type":"filterByKeyword","keyword":"Nallini","dateRange":"overdue","statusFilter":"pending"}
- "how many tasks are done?" → {"type":"aggregate","statusFilter":"done","aggregate":true}
- "list all tasks" → {"type":"listAll"}
- "what's my day looking like" → {"type":"filterByDate","dateRange":"today","statusFilter":"pending"}
- "hello, how are you" → {"type":"conversational"}
- "show me high priority tasks" → {"type":"filterByPriority","priorityFilter":"high"}
- "tasks for work project" → {"type":"filterByProject","project":"work"}

User question: "$question"

JSON only, no markdown, no explanation:''';

    try {
      final response = await AIClient.chat(
        messages: [
          {'role': 'system', 'content': 'You are a JSON-only query parser. Return valid JSON only.'},
          {'role': 'user', 'content': prompt},
        ],
        temperature: 0.0,
        maxTokens: 200,
        purpose: 'nl_query',
      );

      // Extract JSON from response (may have markdown code blocks)
      String jsonStr = response.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceAll('```json', '').replaceAll('```', '').trim();
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final typeStr = json['type'] as String? ?? 'conversational';

      NLQueryType type;
      try {
        type = NLQueryType.values.firstWhere((t) => t.name == typeStr);
      } catch (_) {
        type = NLQueryType.conversational;
      }

      DateRange? dateRange;
      if (json['dateRange'] != null) {
        try {
          dateRange = DateRange.values.firstWhere((d) => d.name == json['dateRange']);
        } catch (_) {}
      }

      return NLQuery(
        type: type,
        keyword: json['keyword'] as String?,
        statusFilter: json['statusFilter'] as String?,
        project: json['project'] as String?,
        priorityFilter: json['priorityFilter'] as String?,
        dateRange: dateRange,
        aggregate: json['aggregate'] as bool? ?? false,
        rawQuestion: question,
      );
    } catch (e) {
      // Fallback: treat as keyword search
      return NLQuery(
        type: NLQueryType.filterByKeyword,
        keyword: question,
        rawQuestion: question,
      );
    }
  }

  /// Execute the structured query against the Drift database.
  Future<List<Task>> _runQuery(NLQuery query) async {
    final allTasks = await db.taskDao.getAllTasks();

    var results = allTasks;

    // Filter by status
    if (query.statusFilter != null && query.statusFilter != 'all') {
      results = results.where((t) => t.status.name == query.statusFilter).toList();
    }

    // Filter by keyword (search in title and notes)
    if (query.keyword != null && query.keyword!.isNotEmpty) {
      final keyword = query.keyword!.toLowerCase();
      results = results.where((t) {
        final titleMatch = t.title.toLowerCase().contains(keyword);
        final notesMatch = (t.notes ?? '').toLowerCase().contains(keyword);
        return titleMatch || notesMatch;
      }).toList();
    }

    // Filter by project
    if (query.project != null && query.project!.isNotEmpty) {
      final project = query.project!.toLowerCase();
      results = results.where((t) => (t.project ?? '').toLowerCase().contains(project)).toList();
    }

    // Filter by priority
    if (query.priorityFilter != null) {
      results = results.where((t) => t.priority.name == query.priorityFilter).toList();
    }

    // Filter by date range
    if (query.dateRange != null) {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      results = results.where((t) {
        final due = t.dueDate;
        if (due == null) return false;

        switch (query.dateRange!) {
          case DateRange.today:
            return due.isAtSameMomentAs(startOfDay) ||
                (due.isAfter(startOfDay) && due.isBefore(startOfDay.add(const Duration(days: 1))));
          case DateRange.thisWeek:
            final endOfWeek = startOfDay.add(Duration(days: 7 - startOfDay.weekday));
            return (due.isAfter(startOfDay.subtract(const Duration(days: 1))) &&
                due.isBefore(endOfWeek.add(const Duration(days: 1))));
          case DateRange.thisMonth:
            final endOfMonth = DateTime(now.year, now.month + 1, 0);
            return due.isBefore(endOfMonth) && due.isAfter(startOfDay.subtract(const Duration(days: 1)));
          case DateRange.overdue:
            return due.isBefore(startOfDay);
          case DateRange.upcoming:
            return due.isAfter(startOfDay.subtract(const Duration(days: 1)));
        }
      }).toList();
    }

    // Sort: high priority first, then by due date
    results.sort((a, b) {
      final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      final pa = priorityOrder[a.priority.name] ?? 1;
      final pb = priorityOrder[b.priority.name] ?? 1;
      if (pa != pb) return pa.compareTo(pb);
      if (a.dueDate != null && b.dueDate != null) return a.dueDate!.compareTo(b.dueDate!);
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;
      return 0;
    });

    return results;
  }

  /// Use AI to format query results as a natural language summary.
  Future<String> _formatResults(NLQuery query, List<Task> tasks) async {
    if (query.type == NLQueryType.conversational) return '';

    if (tasks.isEmpty) {
      return 'No tasks match your query: "${query.rawQuestion}"';
    }

    final taskList = tasks.map((t) {
      final due = t.dueDate != null
          ? ' (due: ${t.dueDate!.month}/${t.dueDate!.day})'
          : '';
      return '• ${t.title} [${t.priority.name}$due]';
    }).join('\n');

    final prompt = '''You are a task assistant. Summarize the following query results in 2-3 sentences, then list the tasks.

Query: "${query.rawQuestion}"
Found ${tasks.length} task(s):

$taskList

Format: brief summary, then numbered or bulleted task list. Be concise.''';

    try {
      return await AIClient.chat(
        messages: [
          {'role': 'user', 'content': prompt},
        ],
        temperature: 0.3,
        maxTokens: 300,
        purpose: 'nl_summary',
      );
    } catch (e) {
      // Fallback: simple text summary
      return 'Found ${tasks.length} task(s):\n$taskList';
    }
  }

  /// Generate a conversational reply for non-task queries.
  Future<String> _conversationalReply(String question) async {
    try {
      return await AIClient.chat(
        messages: [
          {
            'role': 'system',
            'content': 'You are a friendly task assistant. Be brief and helpful. If the user asks about tasks, suggest they rephrase with more detail.',
          },
          {'role': 'user', 'content': question},
        ],
        temperature: 0.5,
        maxTokens: 150,
        purpose: 'conversational',
      );
    } catch (e) {
      return "I couldn't process that. Try asking about your tasks, like 'show me overdue tasks'.";
    }
  }
}
