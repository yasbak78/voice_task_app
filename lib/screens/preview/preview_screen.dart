import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:voice_task_app/core/parser/task_parser.dart' as parser show TaskParser, ParsedTask, Priority;
import 'package:voice_task_app/core/database/app_database.dart';
import 'package:voice_task_app/core/notifications/notification_service.dart';
import 'package:voice_task_app/models/task_model.dart';
import 'package:voice_task_app/providers/task_providers.dart';

/// Preview screen shown after voice parsing, before saving to DB.
/// User can review/edit priority, project, due date, and notes.
class PreviewScreen extends ConsumerStatefulWidget {
  final String transcription;

  const PreviewScreen({super.key, required this.transcription});

  static const route = '/preview';

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  late parser.ParsedTask _parsed;
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _projectController;
  Priority _priority;
  DateTime? _dueDate;
  bool _hasReminder;
  bool _isSaving = false;

  _PreviewScreenState()
      : _priority = Priority.medium,
        _dueDate = null,
        _hasReminder = false;

  @override
  void initState() {
    super.initState();
    _parsed = parser.TaskParser.parse(widget.transcription);
    _titleController = TextEditingController(text: _parsed.title);
    _notesController = TextEditingController(text: _parsed.notes ?? '');
    _projectController = TextEditingController(text: _parsed.project ?? '');
    _priority = _parsed.priority.toDbPriority();
    _dueDate = _parsed.dueDate;
    _hasReminder = _parsed.hasReminder;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _projectController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _saveTask() async {
    setState(() => _isSaving = true);

    final dao = ref.read(taskDaoProvider);
    final taskCompanion = TasksCompanion(
      id: Value(_generateId()),
      title: Value(_titleController.text.trim()),
      notes: _notesController.text.trim().isEmpty ? const Value.absent() : Value(_notesController.text.trim()),
      priority: Value(_priority),
      project: _projectController.text.trim().isEmpty ? const Value.absent() : Value(_projectController.text.trim()),
      dueDate: _dueDate != null ? Value(_dueDate) : const Value.absent(),
      isCalendarEvent: Value(_hasReminder),
      status: Value(TaskStatus.pending),
      createdAt: Value(DateTime.now()),
    );

    await dao.createTask(taskCompanion);

    // Schedule notification if reminder enabled and due date set
    if (_hasReminder && _dueDate != null) {
      final taskId = _generateId();
      await NotificationService.instance.scheduleTaskNotification(
        id: int.parse(taskId.substring(taskId.length - 8)),
        title: 'Task Due: ${_titleController.text.trim()}',
        body: _notesController.text.trim().isEmpty
            ? 'This task is due now'
            : _notesController.text.trim(),
        scheduledDate: _dueDate!,
        taskId: taskId,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task saved!')),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  void _discard() {
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _discard,
            tooltip: 'Discard',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Title'),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Task title',
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            _section('Priority'),
            SegmentedButton<Priority>(
              segments: const [
                ButtonSegment(value: Priority.high, label: Text('High'), icon: Icon(Icons.flag, color: Colors.red)),
                ButtonSegment(value: Priority.medium, label: Text('Medium'), icon: Icon(Icons.flag, color: Colors.orange)),
                ButtonSegment(value: Priority.low, label: Text('Low'), icon: Icon(Icons.flag, color: Colors.blue)),
              ],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
            ),
            const SizedBox(height: 16),

            _section('Project'),
            TextField(
              controller: _projectController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Project (optional)',
              ),
            ),
            const SizedBox(height: 16),

            _section('Due Date'),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Text(_dueDate != null ? _formatDate(_dueDate!) : 'No date set'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            _section('Reminder'),
            SwitchListTile(
              title: const Text('Enable reminder'),
              value: _hasReminder,
              onChanged: (v) => setState(() => _hasReminder = v),
            ),
            const SizedBox(height: 16),

            _section('Notes'),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Additional notes (optional)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _discard,
                    child: const Text('Discard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveTask,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Task'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
}

/// Extension to convert parser Priority to DB Priority.
extension PriorityConverter on parser.Priority {
  Priority toDbPriority() {
    return switch (this) {
      parser.Priority.high => Priority.high,
      parser.Priority.low => Priority.low,
      parser.Priority.medium => Priority.medium,
    };
  }
}
