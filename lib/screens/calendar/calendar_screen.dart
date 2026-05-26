import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:voice_task_app/core/database/app_database.dart';
import 'package:voice_task_app/core/haptics/app_haptics.dart';
import 'package:voice_task_app/core/theme/app_spacing.dart';
import 'package:voice_task_app/providers/task_providers.dart' show allTasksProvider;

/// Calendar screen showing tasks by day with month/week view toggle.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  static const route = '/calendar';

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Task>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  List<Task> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  void _updateEvents(List<Task> tasks) {
    final events = <DateTime, List<Task>>{};
    for (final task in tasks) {
      if (task.dueDate != null) {
        final day = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
        events.putIfAbsent(day, () => []).add(task);
      }
    }
    setState(() => _events = events);
  }

  void _navigateToPrevious() {
    AppHaptics.navigate();
    setState(() {
      if (_calendarFormat == CalendarFormat.month) {
        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
      } else {
        _focusedDay = _focusedDay.subtract(const Duration(days: 7));
      }
    });
  }

  void _navigateToNext() {
    AppHaptics.navigate();
    setState(() {
      if (_calendarFormat == CalendarFormat.month) {
        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
      } else {
        _focusedDay = _focusedDay.add(const Duration(days: 7));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final tasksAsync = ref.watch(allTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Month/Week toggle ──
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                // Navigation arrows + month/year label
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _navigateToPrevious,
                  color: primaryColor,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _calendarFormat == CalendarFormat.month
                          ? _monthYearFormat(_focusedDay)
                          : _weekRangeFormat(_focusedDay),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _navigateToNext,
                  color: primaryColor,
                ),
              ],
            ),
          ),

          // Segmented toggle for Month/Week
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: SegmentedButton<CalendarFormat>(
              segments: const [
                ButtonSegment(
                  value: CalendarFormat.month,
                  label: Text('Month'),
                  icon: Icon(Icons.calendar_month, size: 16),
                ),
                ButtonSegment(
                  value: CalendarFormat.week,
                  label: Text('Week'),
                  icon: Icon(Icons.view_week, size: 16),
                ),
              ],
              selected: {_calendarFormat},
              onSelectionChanged: (formats) {
                AppHaptics.navigate();
                setState(() => _calendarFormat = formats.first);
              },
            ),
          ),

          // Calendar widget
          TableCalendar<Task>(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365 * 2)),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              markersAlignment: Alignment.bottomCenter,
              markerSize: 5,
              markerMargin: const EdgeInsets.symmetric(horizontal: 1),
              selectedDecoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              todayDecoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: primaryColor, width: 2),
              ),
              todayTextStyle: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
              defaultTextStyle: Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
              weekendTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ) ?? const TextStyle(color: Colors.red),
              outsideTextStyle: TextStyle(color: Colors.grey.shade400),
              markersMaxCount: 3,
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: false,
              leftChevronVisible: false,
              rightChevronVisible: false,
              headerPadding: EdgeInsets.zero,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: events.take(3).map((event) {
                    return Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _eventDotColor(event),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            availableGestures: AvailableGestures.horizontalSwipe,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
              CalendarFormat.week: 'Week',
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),

          const Divider(height: 1),

          // Event list for selected day
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                _updateEvents(tasks);
                final selectedEvents = _getEventsForDay(_selectedDay ?? DateTime.now());

                if (selectedEvents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_note, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No tasks for ${_formatDay(_selectedDay ?? DateTime.now())}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, index) {
                    final task = selectedEvents[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          task.status == TaskStatus.done ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: _priorityColor(task.priority),
                        ),
                        title: Text(task.title),
                        subtitle: task.project != null ? Text('📁 ${task.project}') : null,
                        trailing: _priorityBadge(task.priority),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Color _eventDotColor(Task task) {
    return switch (task.priority) {
      Priority.high => const Color(0xFFE53935),
      Priority.medium => const Color(0xFFF59E0B),
      Priority.low => const Color(0xFF4A6FA5),
    };
  }

  Color _priorityColor(Priority priority) {
    return switch (priority) {
      Priority.high => Colors.red,
      Priority.medium => Colors.orange,
      Priority.low => Colors.green,
    };
  }

  Widget _priorityBadge(Priority priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _priorityColor(priority).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority.name.toUpperCase(),
        style: TextStyle(
          color: _priorityColor(priority),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDay(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(day.year, day.month, day.day);
    final diff = selected.difference(today).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'tomorrow';
    if (diff == -1) return 'yesterday';
    return '${day.day}/${day.month}';
  }

  String _monthYearFormat(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _weekRangeFormat(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (startOfWeek.month == endOfWeek.month) {
      return '${months[startOfWeek.month - 1]} ${startOfWeek.day}–${endOfWeek.day}, ${startOfWeek.year}';
    }
    return '${months[startOfWeek.month - 1]} ${startOfWeek.day} – ${months[endOfWeek.month - 1]} ${endOfWeek.day}, ${endOfWeek.year}';
  }
}
