part of '../app_database.dart';

@DriftAccessor(tables: [Tasks])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  Future<List<Task>> getAllTasks() => select(tasks).get();

  Future<List<Task>> getTasksByStatus(TaskStatus status) =>
      (select(tasks)..where((t) => t.status.equals(status.name))).get();

  Future<List<Task>> getTasksDueToday() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (select(tasks)
          ..where(
              (t) => t.dueDate.isBiggerOrEqualValue(startOfDay) & t.dueDate.isSmallerThanValue(endOfDay))
          ..where((t) => t.status.equals(TaskStatus.pending.name)))
        .get();
  }

  Future<Task?> getTaskById(String id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> createTask(TasksCompanion task) => into(tasks).insert(task);

  Future<int> updateTask(Task task) =>
      (update(tasks)..where((t) => t.id.equals(task.id)))
          .write(task.toCompanion(true));

  Future<int> deleteTask(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  Future<int> markComplete(String id) =>
      (update(tasks)..where((t) => t.id.equals(id)))
          .write(TasksCompanion(
        status: Value(TaskStatus.done),
        completedAt: Value(DateTime.now()),
      ));

  Future<int> markIncomplete(String id) =>
      (update(tasks)..where((t) => t.id.equals(id)))
          .write(TasksCompanion(
        status: Value(TaskStatus.pending),
        completedAt: Value(null),
      ));

  Stream<List<Task>> watchAllTasks() => select(tasks).watch();

  Stream<List<Task>> watchTasksDueToday() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (select(tasks)
          ..where(
              (t) => t.dueDate.isBiggerOrEqualValue(startOfDay) & t.dueDate.isSmallerThanValue(endOfDay))
          ..where((t) => t.status.equals(TaskStatus.pending.name)))
        .watch();
  }

  /// Bulk delete tasks by their IDs.
  Future<int> bulkDeleteTasks(List<String> ids) async {
    if (ids.isEmpty) return 0;
    return (delete(tasks)..where((t) => t.id.isIn(ids))).go();
  }

  /// Bulk mark tasks as completed.
  Future<int> bulkMarkComplete(List<String> ids) async {
    if (ids.isEmpty) return 0;
    return (update(tasks)..where((t) => t.id.isIn(ids)))
        .write(TasksCompanion(
      status: Value(TaskStatus.done),
      completedAt: Value(DateTime.now()),
    ));
  }

  /// Delete ALL tasks from the database.
  Future<int> deleteAllTasks() {
    return delete(tasks).go();
  }
}
