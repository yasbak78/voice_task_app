part of '../app_database.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(AppDatabase db) : super(db);

  Future<String?> getValue(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) async {
    final existing = await getValue(key);
    if (existing == null) {
      await into(settings).insert(
        SettingsCompanion(key: Value(key), value: Value(value)),
      );
    } else {
      await (update(settings)..where((s) => s.key.equals(key)))
          .write(SettingsCompanion(value: Value(value)));
    }
  }

  Future<Map<String, String>> getAllSettings() async {
    final rows = await select(settings).get();
    return {for (final row in rows) row.key: row.value};
  }

  Future<void> deleteValue(String key) =>
      (delete(settings)..where((s) => s.key.equals(key))).go();
}
