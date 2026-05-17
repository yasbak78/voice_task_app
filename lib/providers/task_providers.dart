import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/app_database.dart';

final dbProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final taskDaoProvider = Provider((ref) {
  return ref.watch(dbProvider).tasksDao;
});

final calendarDaoProvider = Provider((ref) {
  return ref.watch(dbProvider).calendarDao;
});

final settingsDaoProvider = Provider((ref) {
  return ref.watch(dbProvider).settingsDao;
});

final allTasksProvider = StreamProvider((ref) {
  return ref.watch(taskDaoProvider).watchAllTasks();
});

final todayTasksProvider = StreamProvider((ref) {
  return ref.watch(taskDaoProvider).watchTasksDueToday();
});

final taskStatsProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  final tasks = ref.watch(allTasksProvider);
  return tasks.when(
    data: (list) => AsyncValue.data({
      'total': list.length,
      'pending':
          list.where((t) => t.status == TaskStatus.pending).length,
      'done': list.where((t) => t.status == TaskStatus.done).length,
      'overdue': list
          .where((t) =>
              t.status != TaskStatus.done &&
              t.dueDate != null &&
              DateTime.now().isAfter(t.dueDate!))
          .length,
    }),
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
