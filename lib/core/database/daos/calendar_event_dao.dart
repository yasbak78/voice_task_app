part of '../app_database.dart';

@DriftAccessor(tables: [CalendarEvents])
class CalendarEventDao extends DatabaseAccessor<AppDatabase>
    with _$CalendarEventDaoMixin {
  CalendarEventDao(super.db);

  Future<List<CalendarEvent>> getEventsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (select(calendarEvents)
          ..where(
              (e) => e.startTime.isBiggerOrEqualValue(start) & e.startTime.isSmallerThanValue(end)))
        .get();
  }

  Future<List<CalendarEvent>> getEventsInRange(DateTime start, DateTime end) {
    return (select(calendarEvents)
          ..where((e) =>
              e.startTime.isBiggerOrEqualValue(start) &
              e.startTime.isSmallerThanValue(end))
          ..orderBy([(e) => OrderingTerm(expression: e.startTime)]))
        .get();
  }

  Future<int> createEvent(CalendarEventsCompanion event) =>
      into(calendarEvents).insert(event);

  Future<bool> updateEvent(CalendarEvent event) =>
      update(calendarEvents).replace(event);

  Future<int> deleteEvent(String id) =>
      (delete(calendarEvents)..where((e) => e.id.equals(id))).go();
}
