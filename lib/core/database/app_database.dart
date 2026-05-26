import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';
part 'daos/task_dao.dart';
part 'daos/calendar_event_dao.dart';
part 'daos/settings_dao.dart';

enum Priority { high, medium, low }
enum TaskStatus { pending, inProgress, done, archived }

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get priority =>
      textEnum<Priority>().withDefault(Constant('medium'))();
  TextColumn get project => text().nullable()();
  TextColumn get status =>
      textEnum<TaskStatus>().withDefault(Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  BoolColumn get hasReminder => boolean().withDefault(Constant(false))();
  TextColumn get reminderTime => text().nullable()();
  BoolColumn get isCalendarEvent => boolean().withDefault(Constant(false))();
}

class CalendarEvents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  TextColumn get color => text().withDefault(Constant('blue'))();
  TextColumn get taskId => text().nullable()();
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
}

@DriftDatabase(tables: [Tasks, CalendarEvents, Settings], daos: [TaskDao, CalendarEventDao, SettingsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.test(super.e);

  @override
  int get schemaVersion => 1;

  TaskDao get tasksDao => TaskDao(this);
  CalendarEventDao get calendarDao => CalendarEventDao(this);
  @override
  SettingsDao get settingsDao => SettingsDao(this);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
