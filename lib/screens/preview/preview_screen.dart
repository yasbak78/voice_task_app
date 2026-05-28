import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';
import 'package:voice_task_app/core/haptics/app_haptics.dart';
import 'package:voice_task_app/core/parser/task_parser.dart' as parser show TaskParser, ParsedTask;
import 'package:voice_task_app/core/database/app_database.dart';
import 'package:voice_task_app/core/notifications/notification_service.dart' show NotificationService, ReminderSound;
import 'package:voice_task_app/providers/task_providers.dart';
import 'package:voice_task_app/services/ai_task_parser.dart';

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
  Duration? reminderOffset; // e.g. Duration(minutes: 10) = "10 min before"
  ReminderSound reminderSound; // sound type for notification
  bool checked; // whether to include this task when saving

  _EditableTask(this.parsed)
      : titleController = TextEditingController(),
        notesController = TextEditingController(),
        projectController = TextEditingController(),
        priority = Priority.medium,
        dueDate = null,
        dueTime = null,
        hasReminder = false,
        reminderOffset = null,
        reminderSound = ReminderSound.systemDefault,
        checked = true;

  void syncFromParsed() {
    titleController.text = parsed.title;
    notesController.text = parsed.notes ?? '';
    projectController.text = parsed.project ?? '';
    priority = parsed.priority;
    dueDate = parsed.dueDate;
    dueTime = parsed.dueTime;
    hasReminder = parsed.hasReminder;
    reminderOffset = parsed.reminderOffset;
    reminderSound = parsed.reminderSound;
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

  /// When the reminder notification should fire = dueDate - reminderOffset.
  DateTime? get reminderFireTime {
    final due = combinedDueDate;
    if (due == null || !hasReminder || reminderOffset == null) return null;
    return due.subtract(reminderOffset!);
  }

  /// Human-readable label for the reminder, e.g. "10 min before (1:50 PM)".
  String? get reminderLabel {
    final fire = reminderFireTime;
    if (fire == null) return null;
    final offset = reminderOffset!;
    String offsetStr;
    if (offset.inMinutes < 60) {
      offsetStr = '${offset.inMinutes} min before';
    } else if (offset.inHours == 1 && offset.inMinutes % 60 == 0) {
      offsetStr = '1 hour before';
    } else {
      offsetStr = '${offset.inHours}h ${offset.inMinutes % 60}m before';
    }
    final timeStr = DateFormat('h:mm a').format(fire);
    return '$offsetStr ($timeStr)';
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
      reminderOffset: reminderOffset,
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
  bool _isAiProcessing = true; // Start true — we try AI first
  bool _usedAi = false; // Whether AI parser succeeded
  String? _parseError; // Error message if AI fails
  int _taskCount = 0; // Number of tasks parsed

  @override
  void initState() {
    super.initState();
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    final input = widget.transcription.trim();
    if (input.isEmpty) {
      setState(() {
        _tasks.add(_EditableTask(const parser.ParsedTask(title: 'Untitled task'))
          ..syncFromParsed());
        _isInitialized = true;
        _isAiProcessing = false;
      });
      return;
    }

    // Try AI parser first
    try {
      final aiResult = await AITaskParser.splitAndParse(input);

      if (!mounted) return;

      if (aiResult.isConversational) {
        setState(() {
          _conversationalReply = aiResult.conversationalReply;
          _isInitialized = true;
          _isAiProcessing = false;
          _usedAi = true;
        });
        return;
      }

      final tasksToUse = aiResult.tasks.isNotEmpty
          ? aiResult.tasks
          : [parser.TaskParser.parse(input)];

      setState(() {
        for (final task in tasksToUse) {
          final editable = _EditableTask(task)..syncFromParsed();
          _tasks.add(editable);
        }
        _isInitialized = true;
        _isAiProcessing = false;
        _usedAi = true;
        _taskCount = _tasks.length;
      });
    } catch (e) {
      // AI failed — fallback to rule-based parser
      if (!mounted) return;
      _fallbackToRuleBased(input);
    }
  }

  void _fallbackToRuleBased(String input) {
    final result = parser.TaskParser.splitAndParse(input);

    if (result.isConversational) {
      setState(() {
        _conversationalReply = result.conversationalReply;
        _isInitialized = true;
        _isAiProcessing = false;
        _usedAi = false;
        _parseError = 'AI unavailable — using local parser';
      });
      return;
    }

    final tasksToUse = result.tasks.isNotEmpty
        ? result.tasks
        : [parser.TaskParser.parse(input)];

    setState(() {
      for (final task in tasksToUse) {
        final editable = _EditableTask(task)..syncFromParsed();
        _tasks.add(editable);
      }
      _isInitialized = true;
      _isAiProcessing = false;
      _usedAi = false;
      _parseError = 'AI unavailable — using local parser';
      _taskCount = _tasks.length;
    });
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
        hasReminder: Value(editable.hasReminder),
        reminderTime: editable.reminderOffset != null
            ? Value(_formatReminderOffset(editable.reminderOffset!))
            : const Value.absent(),
        reminderSound: Value(editable.reminderSound.id),
        isCalendarEvent: Value(editable.hasReminder),
        status: Value(TaskStatus.pending),
        createdAt: Value(DateTime.now()),
      );

      await dao.createTask(taskCompanion);
      savedCount++;

      // Schedule notification if reminder enabled and due date set
      // Schedule notification if task has a due date
      if (parsed.dueDate != null) {
        final taskId = _generateId();
        final notificationTime = editable.reminderFireTime ?? parsed.dueDate!;
        final isReminder = editable.hasReminder && editable.reminderOffset != null;

        // Only schedule if the notification time is in the future
        if (notificationTime.isAfter(DateTime.now())) {
          await NotificationService.instance.scheduleTaskNotification(
            id: int.parse(taskId.substring(taskId.length - 8)),
            title: isReminder ? 'Reminder: ${parsed.title}' : 'Task Due: ${parsed.title}',
            body: isReminder
                ? 'Upcoming: ${parsed.notes ?? parsed.title}'
                : (parsed.notes ?? 'This task is due now'),
            scheduledDate: notificationTime,
            taskId: taskId,
            sound: editable.reminderSound,
          );
        }
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
    // Loading state while AI processes
    if (_isAiProcessing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Review Tasks'),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Analyzing with AI...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

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
              // AI badge — shows which parser was used
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _usedAi
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _usedAi
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _usedAi ? Icons.auto_awesome : Icons.build,
                      size: 10,
                      color: _usedAi
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _usedAi ? 'AI' : 'Local',
                      style: TextStyle(
                        fontSize: 10,
                        color: _usedAi
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_taskCount > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_taskCount tasks',
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
          // Fallback warning banner
          if (_parseError != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _parseError!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                        setState(() {
                          editable.hasReminder = v;
                          if (v && editable.reminderOffset == null) {
                            // Default to 10 min before when first enabled
                            editable.reminderOffset = const Duration(minutes: 10);
                          }
                        });
                      },
                    ),
                    const Text('Reminder', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
            // Reminder chip - shows calculated time when reminder is on
            if (editable.hasReminder && editable.reminderOffset != null)
              _buildReminderChip(index, editable),
          ],
        ),
      ),
    );
  }

  /// Reminder chip showing the calculated fire time, tappable to change offset.
  Widget _buildReminderChip(int index, _EditableTask editable) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => _showReminderSelector(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_active,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                editable.reminderLabel ?? 'Reminder set',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                _soundIcon(editable.reminderSound),
                size: 12,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.edit,
                size: 12,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom sheet to select reminder offset type and sound.
  Future<void> _showReminderSelector(int taskIndex) async {
    AppHaptics.tap();
    final editable = _tasks[taskIndex];

    // Common offset options
    final offsetOptions = <({Duration? offset, String label, IconData icon})>[
      (offset: const Duration(minutes: 5), label: '5 min before', icon: Icons.notifications),
      (offset: const Duration(minutes: 10), label: '10 min before', icon: Icons.notifications),
      (offset: const Duration(minutes: 15), label: '15 min before', icon: Icons.notifications),
      (offset: const Duration(minutes: 30), label: '30 min before', icon: Icons.notifications),
      (offset: const Duration(hours: 1), label: '1 hour before', icon: Icons.notifications_active),
      (offset: null, label: 'At time of task', icon: Icons.access_alarm),
    ];

    // Sound options
    final soundOptions = ReminderSound.values.where((s) => s != ReminderSound.systemDefault).toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Reminder Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const Divider(height: 1),
                // Time section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'WHEN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                ...offsetOptions.map((opt) {
                  final isSelected = editable.reminderOffset == opt.offset;
                  return ListTile(
                    leading: Icon(opt.icon, color: isSelected ? Theme.of(context).colorScheme.primary : null),
                    title: Text(opt.label),
                    trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                    onTap: () {
                      setState(() {
                        editable.reminderOffset = opt.offset;
                        if (opt.offset == null) {
                          editable.reminderOffset = Duration.zero;
                        }
                      });
                    },
                  );
                }),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('Custom time...'),
                  onTap: () async {
                    await _pickCustomReminderOffset(taskIndex);
                  },
                ),
                const Divider(height: 1),
                // Sound section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SOUND',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                ...soundOptions.map((sound) {
                  final isSelected = editable.reminderSound == sound;
                  return ListTile(
                    leading: Icon(_soundIcon(sound), color: isSelected ? Theme.of(context).colorScheme.primary : null),
                    title: Text(sound.label),
                    trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                    onTap: () {
                      setState(() {
                        editable.reminderSound = sound;
                      });
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Get icon for a reminder sound.
  IconData _soundIcon(ReminderSound sound) {
    return switch (sound) {
      ReminderSound.silent => Icons.volume_off,
      ReminderSound.gentlePing => Icons.waves,
      ReminderSound.classicBell => Icons.notifications,
      ReminderSound.urgentBeep => Icons.error_outline,
      ReminderSound.melody => Icons.music_note,
      ReminderSound.systemDefault => Icons.volume_up,
    };
  }

  /// Time picker for custom reminder offset.
  Future<void> _pickCustomReminderOffset(int taskIndex) async {
    final editable = _tasks[taskIndex];
    final due = editable.combinedDueDate ?? DateTime.now();

    // Let user pick a time for the reminder
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(due),
      helpText: 'Reminder time',
    );
    if (picked != null) {
      final reminderTime = DateTime(
        due.year, due.month, due.day,
        picked.hour, picked.minute,
      );
      final offset = due.difference(reminderTime);
      if (offset.isNegative) {
        // Reminder time is after due date, warn user
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder time is after the task time')),
        );
        return;
      }
      setState(() {
        editable.reminderOffset = offset;
      });
    }
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

  /// Format reminder offset for DB storage (e.g. "10m", "1h", "1h30m").
  String _formatReminderOffset(Duration offset) {
    if (offset == Duration.zero) return '0m';
    final hours = offset.inHours;
    final minutes = offset.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) return '${hours}h${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }
}
