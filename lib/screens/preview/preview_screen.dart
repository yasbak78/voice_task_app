import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:voice_task_app/core/haptics/app_haptics.dart';
import 'package:voice_task_app/core/parser/task_parser.dart' as parser show TaskParser, ParsedTask;
import 'package:voice_task_app/core/database/app_database.dart';
import 'package:voice_task_app/core/notifications/notification_service.dart';
import 'package:voice_task_app/providers/task_providers.dart';

/// Preview screen shown after voice parsing, before saving to DB.
/// Shows the raw transcription at the top, then a list of parsed tasks
/// that the user can review/edit before saving.
class PreviewScreen extends ConsumerStatefulWidget {
  final String transcription;

  const PreviewScreen({super.key, required this.transcription});

  static const route = '/preview';

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

/// Mutable wrapper for editing a parsed task in the UI.
class _EditableTask {
  parser.ParsedTask parsed;
  TextEditingController titleController;
  TextEditingController notesController;
  TextEditingController projectController;
  Priority priority;
  DateTime? dueDate;
  DateTime? dueTime;
  bool hasReminder;
  bool checked; // whether to include this task when saving

  _EditableTask(this.parsed)
      : titleController = TextEditingController(),
        notesController = TextEditingController(),
        projectController = TextEditingController(),
        priority = Priority.medium,
        dueDate = null,
        dueTime = null,
        hasReminder = false,
        checked = true;

  void syncFromParsed() {
    titleController.text = parsed.title;
    notesController.text = parsed.notes ?? '';
    projectController.text = parsed.project ?? '';
    priority = parsed.priority;
    dueDate = parsed.dueDate;
    dueTime = parsed.dueTime;
    hasReminder = parsed.hasReminder;
  }

  /// Combined DateTime for saving to DB (date + time merged).
  DateTime? get combinedDueDate {
    if (dueDate == null && dueTime == null) return null;
    if (dueDate != null && dueTime == null) return dueDate;
    if (dueDate == null && dueTime != null) {
      // Time only, no date -> today + time
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, dueTime!.hour, dueTime!.minute);
    }
    // Both date and time -> merge
    return DateTime(
      dueDate!.year, dueDate!.month, dueDate!.day,
      dueTime!.hour, dueTime!.minute,
    );
  }

  parser.ParsedTask toParsed() {
    return parser.ParsedTask(
      title: titleController.text.trim(),
      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      priority: priority,
      project: projectController.text.trim().isEmpty ? null : projectController.text.trim(),
      dueDate: combinedDueDate,
      dueTime: dueTime,
      hasReminder: hasReminder,
    );
  }

  void dispose() {
    titleController.dispose();
    notesController.dispose();
    projectController.dispose();
  }
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  final List<_EditableTask> _tasks = [];
  String? _conversationalReply;
  bool _isSaving = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    final input = widget.transcription.trim();
    if (input.isEmpty) {
      _tasks.add(_EditableTask(const parser.ParsedTask(title: 'Untitled task'))
        ..syncFromParsed());
      _isInitialized = true;
      return;
    }

    final result = parser.TaskParser.splitAndParse(input);

    if (result.isConversational) {
      _conversationalReply = result.conversationalReply;
      _isInitialized = true;
      return;
    }

    if (result.tasks.isEmpty) {
      // Fallback: parse the whole input as a single task
      final single = parser.TaskParser.parse(input);
      final editable = _EditableTask(single)..syncFromParsed();
      _tasks.add(editable);
    } else {
      for (final task in result.tasks) {
        final editable = _EditableTask(task)..syncFromParsed();
        _tasks.add(editable);
      }
    }
    _isInitialized = true;
  }

  @override
  void dispose() {
    for (final task in _tasks) {
      task.dispose();
    }
    super.dispose();
  }

  Future<void> _saveAll() async {
    AppHaptics.complete();
    setState(() => _isSaving = true);

    final dao = ref.read(taskDaoProvider);
    int savedCount = 0;

    for (final editable in _tasks) {
      if (!editable.checked) continue;

      final parsed = editable.toParsed();
      if (parsed.title.isEmpty) continue;

      final taskCompanion = TasksCompanion(
        id: Value(_generateId()),
        title: Value(parsed.title),
        notes: parsed.notes != null ? Value(parsed.notes) : const Value.absent(),
        priority: Value(parsed.priority),
        project: parsed.project != null ? Value(parsed.project) : const Value.absent(),
        dueDate: parsed.dueDate != null ? Value(parsed.dueDate) : const Value.absent(),
        isCalendarEvent: Value(parsed.hasReminder),
        status: Value(TaskStatus.pending),
        createdAt: Value(DateTime.now()),
      );

      await dao.createTask(taskCompanion);
      savedCount++;

      // Schedule notification if reminder enabled and due date set
      if (parsed.hasReminder && parsed.dueDate != null) {
        final taskId = _generateId();
        await NotificationService.instance.scheduleTaskNotification(
          id: int.parse(taskId.substring(taskId.length - 8)),
          title: 'Task Due: ${parsed.title}',
          body: parsed.notes ?? 'This task is due now',
          scheduledDate: parsed.dueDate!,
          taskId: taskId,
        );
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$savedCount task${savedCount == 1 ? '' : 's'} saved!')),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  Future<void> _pickDate(int taskIndex) async {
    AppHaptics.tap();
    final editable = _tasks[taskIndex];
    final picked = await showDatePicker(
      context: context,
      initialDate: editable.dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        // Preserve existing time when picking a new date
        final existingHour = editable.dueDate?.hour ?? editable.dueTime?.hour;
        final existingMinute = editable.dueDate?.minute ?? editable.dueTime?.minute;
        if (existingHour != null && existingMinute != null) {
          editable.dueDate = DateTime(picked.year, picked.month, picked.day, existingHour, existingMinute);
        } else {
          editable.dueDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime(int taskIndex) async {
    AppHaptics.tap();
    final editable = _tasks[taskIndex];
    final now = DateTime.now();
    final initialHour = editable.dueTime?.hour ?? editable.dueDate?.hour ?? now.hour;
    final initialMinute = editable.dueTime?.minute ?? editable.dueDate?.minute ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );
    if (picked != null) {
      setState(() {
        editable.dueTime = DateTime(
          now.year, now.month, now.day, picked.hour, picked.minute,
        );
        // If a date is set, merge the picked time into it
        if (editable.dueDate != null) {
          editable.dueDate = DateTime(
            editable.dueDate!.year, editable.dueDate!.month, editable.dueDate!.day,
            picked.hour, picked.minute,
          );
        }
      });
    }
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + _tasks.hashCode.toString();
  }

  void _discard() {
    AppHaptics.delete();
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Conversational reply
    if (_conversationalReply != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reply'),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _discard,
              tooltip: 'Close',
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _conversationalReply!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _discard,
            tooltip: 'Discard',
          ),
        ],
      ),
      body: Column(
        children: [
          // Transcription card at top
          _buildTranscriptionCard(),

          // Task list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                return _buildTaskCard(index);
              },
            ),
          ),

          // Save button at bottom
          _buildSaveBar(),
        ],
      ),
    );
  }

  Widget _buildTranscriptionCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Transcription',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              if (_tasks.length > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_tasks.length} tasks',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.transcription,
            style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(int index) {
    final editable = _tasks[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox + title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: editable.checked,
                  onChanged: (v) => setState(() => editable.checked = v ?? false),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: editable.titleController,
                        decoration: const InputDecoration(
                          border: UnderlineInputBorder(),
                          hintText: 'Task title',
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: editable.notesController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Notes (optional)',
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Priority
            SegmentedButton<Priority>(
              segments: const [
                ButtonSegment(value: Priority.high, label: Text('High'), icon: Icon(Icons.flag, color: Colors.red)),
                ButtonSegment(value: Priority.medium, label: Text('Medium'), icon: Icon(Icons.flag, color: Colors.orange)),
                ButtonSegment(value: Priority.low, label: Text('Low'), icon: Icon(Icons.flag, color: Colors.blue)),
              ],
              selected: {editable.priority},
              onSelectionChanged: (s) => setState(() {
                AppHaptics.tap();
                editable.priority = s.first;
              }),
            ),
            const SizedBox(height: 8),

            // Project
            TextField(
              controller: editable.projectController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Project (optional)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),

            // Due date + time + reminder row
            Row(
              children: [
                // Date chip
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            editable.dueDate != null ? _formatDate(editable.dueDate!) : 'No date',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Time chip
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _formatTime(editable),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Reminder switch
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: editable.hasReminder,
                      onChanged: (v) {
                        AppHaptics.tap();
                        setState(() => editable.hasReminder = v);
                      },
                    ),
                    const Text('Reminder', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveBar() {
    final checkedCount = _tasks.where((t) => t.checked).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '$checkedCount of ${_tasks.length} tasks',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: (_isSaving || checkedCount == 0) ? null : _saveAll,
              child: _isSaving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save All'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    final diff = date.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _formatTime(_EditableTask editable) {
    final hour = editable.dueTime?.hour ?? editable.dueDate?.hour;
    final minute = editable.dueTime?.minute ?? editable.dueDate?.minute;
    if (hour == null || minute == null) return 'No time';
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }
}
