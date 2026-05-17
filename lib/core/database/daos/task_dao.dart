part of '../app_database.dart';

@DriftAccessor(tables: [Tasks])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(AppDatabase db) : super(db);

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

  Future<bool> updateTask(Task task) => update(tasks).replace(task);

  Future<int> deleteTask(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  Future<int> markComplete(String id) =>
      (update(tasks)..where((t) => t.id.equals(id)))
          .write(TasksCompanion(
        status: Value(TaskStatus.done),
        completedAt: Value(DateTime.now()),
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
}
