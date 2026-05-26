# Voice Task App — Project Documentation

> **Stable Baseline:** v1.0.6+10 (v9 APK) — May 26, 2026
> **Git Commit:** `8167c20` — "feat: whisper.cpp FFI struct complete"
> **Status:** 117/117 tests passing · `flutter analyze` clean · APK built & uploaded

---

## Table of Contents

1. [Overview](#1-overview)
2. [Build Environment](#2-build-environment)
3. [Architecture](#3-architecture)
4. [Frontend (Flutter UI)](#4-frontend-flutter-ui)
5. [Whisper STT Pipeline](#5-whisper-stt-pipeline)
6. [Task Parser (NLP)](#6-task-parser-nlp)
7. [Database Layer](#7-database-layer)
8. [Notifications](#8-notifications)
9. [Test Suite](#9-test-suite)
10. [Known Decisions & Workarounds](#10-known-decisions--workarounds)
11. [Build & Release Process](#11-build--release-process)
12. [Troubleshooting Guide](#12-troubleshooting-guide)

---

## 1. Overview

Voice Task App is a Flutter Android application for voice-first task management. Users record spoken commands, which are transcribed locally using whisper.cpp (on-device, no API keys), parsed into structured tasks with dates/times/priorities, stored in SQLite via Drift ORM, and surfaced with local notifications.

**Key capabilities:**
- On-device speech-to-text (whisper.cpp, no internet required after model download)
- Natural language task parsing (dates, times, priorities, projects, reminders)
- Multi-intent splitting ("create task A for tomorrow and task B for Friday")
- Relative time support ("remind me in 10 minutes", "in half an hour")
- Calendar view with month/week navigation
- Local notifications with exact alarm scheduling
- Backup/restore of task database

---

## 2. Build Environment

| Component | Version | Path |
|---|---|---|
| Flutter SDK | 3.27.3 (stable) | `~/development/flutter/` |
| Dart SDK | 3.6.1 | Bundled with Flutter |
| JDK | 17.0.2 | `~/.local/opt/jdk-17.0.2` |
| Whisper model | `ggml-tiny.en-q5_1.bin` | Bundled in `assets/models/` |
| Host OS | WSL2 (Windows) | `/home/yasbak/` |

### Required Environment Variables for APK Build

```bash
export JAVA_HOME=~/.local/opt/jdk-17.0.2
export PATH=$JAVA_HOME/bin:$PATH
```

Without `JAVA_HOME`, Gradle fails silently or picks the wrong JDK version.

### App Metadata

| Field | Value |
|---|---|
| Package ID | `com.voicetask.voice_task_app` |
| Version | `1.0.6` (versionCode: `10`) |
| Min SDK | 23 (Android 6.0) |
| Target SDK | Flutter default |
| ABI Filters | `armeabi-v7a`, `arm64-v8a`, `x86_64` |
| APK Size | ~60 MB |

---

## 3. Architecture

```
lib/
├── core/
│   ├── stt/              # Whisper STT engine
│   │   ├── whisper_ffi.dart       # FFI bindings to libwhisper.so
│   │   ├── whisper_service.dart   # High-level transcribe() API
│   │   ├── whisper_model_manager.dart  # Model download/caching
│   │   ├── audio_recorder.dart    # Recording with `record` package
│   │   └── wav_converter.dart     # 16kHz mono 16-bit WAV conversion
│   ├── parser/
│   │   └── task_parser.dart       # NLP: transcription → structured task
│   ├── database/
│   │   ├── app_database.dart      # Drift schema (Tasks, CalendarEvents, Settings)
│   │   └── daos/                  # Data access objects
│   ├── notifications/
│   │   └── notification_service.dart  # flutter_local_notifications wrapper
│   ├── theme/
│   │   └── app_theme.dart         # Color scheme, typography
│   ├── haptics/
│   │   └── haptic_feedback.dart   # Tactile feedback utility
│   ├── crash/
│   │   └── crash_handler.dart     # Error boundary & reporting
│   └── update/
│       └── update_checker.dart    # Version update detection
├── models/                        # Data models (VoiceTask, EditableTask)
├── providers/                     # Riverpod state providers
├── screens/
│   ├── home/                      # Main task list
│   ├── record/                    # Recording screen with waveform
│   ├── preview/                   # Post-transcription task preview/edit
│   ├── task_detail/               # Single task view
│   ├── calendar/                  # Calendar month/week view
│   ├── settings/                  # App settings
│   └── onboarding/                # First-run setup
├── services/                      # Business logic services
├── widgets/                       # Reusable UI components
└── main.dart                      # App entry, routing via onGenerateRoute
```

**State Management:** Riverpod (`flutter_riverpod ^2.5.0`)
**Database:** Drift ORM (`drift ^2.20.0`) backed by SQLite
**Notifications:** `flutter_local_notifications ^19.5.0`
**STT:** whisper.cpp via Dart FFI

---

## 4. Frontend (Flutter UI)

### Screen Flow

```
[Home Screen] → Tap mic → [Record Screen]
                           ↓ (stop recording)
                    [Preview Screen] ← edit tasks
                           ↓ (confirm)
                      [Home Screen] (tasks saved)
```

### Key Screens

**Record Screen (`lib/screens/record/record_screen.dart`)**
- Uses `AudioRecorderService` for recording state machine
- States: `idle → recording → processing → done/error`
- Shows real-time amplitude waveform via `amplitudeStream`
- Records at 16kHz, mono, WAV format (whisper-compatible natively)
- Permission handling via `permission_handler`

**Preview Screen (`lib/screens/preview/preview_screen.dart`)**
- Receives transcription via route arguments (`settings.arguments`)
- Calls `TaskParser.splitAndParse()` to break multi-intent input into tasks
- Shows editable task cards with due date/time pickers
- Uses Riverpod `allTasksProvider` for persistence

**Home Screen (`lib/screens/home/`)**
- Task list with filtering (by project, priority, status)
- Completed tasks use `task.completedAt != null` (not enum status)
- Swipe-to-complete, tap-to-detail

**Calendar Screen (`lib/screens/calendar/`)**
- Uses `table_calendar ^3.1.0`
- Month and week view modes
- Highlights days with tasks/events

### Routing

Dynamic routing via `onGenerateRoute` in `main.dart`:
- `/` → Home screen
- `/record` → Record screen
- `/preview?text=...` → Preview screen with transcription
- `/task/:id` → Task detail

### Critical UI Patterns

- **Riverpod `StateProvider` overrides:** Must use `.overrideWith((ref) => value)` for sync injection in tests
- **Riverpod `StreamProvider` overrides:** Must use `.overrideWithValue(AsyncValue.data(...))`
- **Completion check:** `task.completedAt != null` (NOT `task.status == TaskStatus.done`)
- **Deprecated API:** `.withValues(alpha: X)` replaces `.withOpacity(X)`

---

## 5. Whisper STT Pipeline

### Architecture

```
[Microphone] → AudioRecorderService → .wav file
     ↓
WavConverter.convertToWhisperFormat() → validates/converts to 16kHz mono 16-bit
     ↓
WhisperService.initialize() → loads model, creates context
     ↓
WhisperService.transcribe() → runs whisper_full on PCM samples
     ↓
Raw transcript text → TaskParser.splitAndParse()
```

### Whisper FFI Bindings (`whisper_ffi.dart`)

- **Library:** `libwhisper.so` loaded via `DynamicLibrary.open()`
- **Version compatibility:** whisper.cpp v1.7.x
- **Key pattern:** Uses `_by_ref` functions to avoid Dart FFI struct-by-value issues
- **Structs defined:** `WhisperContextParams`, `WhisperFullParams` (27+ fields)
- **Functions bound:** `whisper_init_from_file_with_params`, `whisper_full`, `whisper_full_n_segments`, `whisper_full_get_segment_text`

### WhisperService (`whisper_service.dart`)

1. **Initialization:** Loads `ggml-tiny.en-q5_1.bin` model, creates whisper context with `useGpu = false` (CPU-only for Android stability)
2. **Transcription flow:**
   - Convert audio to whisper-compatible WAV via `WavConverter`
   - Validate WAV format (16kHz, mono, 16-bit PCM)
   - Skip 44-byte WAV header to extract raw PCM data
   - Convert 16-bit PCM to float32 array (whisper.cpp expects `float[-1.0, 1.0]`)
   - Call `whisper_full()` with greedy sampling strategy
   - Extract text from segments via `whisper_full_get_segment_text()`
   - Free native memory (`whisper_free`, `calloc.free`)

### Model Management (`whisper_model_manager.dart`)

- **Default model:** `ggml-tiny.en-q5_1.bin` (~75MB, English-only, quantized)
- **Source priority:** Bundled assets → HuggingFace download fallback
- **Cache location:** `getApplicationSupportDirectory()/whisper_models/`
- **Download retry:** 3 attempts with exponential backoff (2s, 4s, 6s)
- **Verification:** File must be > 1MB to be considered valid

### WavConverter (`wav_converter.dart`)

**Requirements for whisper.cpp:**
- Sample rate: 16,000 Hz
- Channels: 1 (mono)
- Bits per sample: 16
- Format: PCM (uncompressed WAV)

Checks existing WAV headers at byte offsets:
- Offset 24: sample rate (uint32 LE)
- Offset 22: channels (uint16 LE)
- Offset 34: bits per sample (uint16 LE)

### AudioRecorderService (`audio_recorder.dart`)

- Package: `record ^5.1.0`
- Config: `RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1)`
- Output: `/tmp/recording_<timestamp>.wav`
- Provides `amplitudeStream` for real-time waveform visualization
- Permission: `Permission.microphone`

---

## 6. Task Parser (NLP)

### Entry Point

```dart
ParserResult TaskParser.splitAndParse(String transcription)
ParsedTask TaskParser.parse(String text)
```

### Parsing Pipeline (order matters!)

1. **Relative time extraction** — "in 10 minutes", "in half an hour" (runs FIRST to avoid conflicts with absolute time parsing)
2. **Filler word removal** — strips "um", "uh", "I want to", "please", etc.
3. **Reminder detection** — "remind me", "set a reminder", "alarm"
4. **Priority detection** — "urgent", "high priority", "ASAP", "no rush"
5. **Project extraction** — "for the X project", "project: X"
6. **Absolute date parsing** — "tomorrow", "next week", "on Friday"
7. **Absolute time parsing** — "at 3pm", "1:45pm", "14.30"

### Regex Patterns

| Pattern | Regex | Examples |
|---|---|---|
| Relative time | `in\s+(\d+)\s*(minutes\|minute\|mins\|min\|hours\|hour\|hrs\|hr)` | "in 10 minutes", "in 2 hours" |
| Half hour | `in\s+half\s+an?\s+hour` | "in half an hour" |
| Reminder | `(remind\s*me\|set\s*(?:a\s*)?reminder\|alarm\|notify\s*me\|alert\s*me)` | "remind me", "set a reminder" |
| Time | `(at\s+)?(\d{1,2}[:.\s]?\d{0,2})\s*(am\|pm\|a\.?m\.?\|p\.?m\.?)` | "at 3pm", "1.45pm", "145pm" |
| High priority | `(high\s*pri(ority)?\|urgent\|asap\|critical\|immediately)` | "urgent", "ASAP" |
| Filler words | `^(um\|uh\|so\|like\|I need to\|I want to\|wanna\|just)+` | "I want to call mom" → "call mom" |

### Fixed Day Offsets

| Phrase | Offset (days) |
|---|---|
| today | 0 |
| tomorrow | +1 |
| yesterday | -1 |
| in a few days | +3 |
| this weekend | +5 |
| next week / in a week | +7 |
| last week | -7 |
| in two weeks | +14 |
| next month / in a month | +30 |

### Important: Regex Alternation Order

The `_relativeTimePattern` must match **plural forms before singular**:
```dart
r'in\s+(\d+)\s*(minutes|minute|mins|min|hours|hour|hrs|hr)\b'
```
If "minute" comes before "minutes", the regex captures "minute" and leaves a trailing "s", breaking the offset calculation.

### ParsedTask Model

```dart
class ParsedTask {
  final String title;        // Cleaned task title
  final String? notes;       // Optional notes
  final Priority priority;   // high, medium, low
  final String? project;     // Project assignment
  final DateTime? dueDate;   // Due date (day)
  final DateTime? dueTime;   // Due time (hour:minute)
  final bool hasReminder;    // Whether notification should fire
}
```

### ParserResult Model

```dart
class ParserResult {
  final List<ParsedTask> tasks;        // Parsed tasks
  final String? conversationalReply;   // If input was conversational, not a task
  bool get isConversational => tasks.isEmpty && conversationalReply != null;
}
```

---

## 7. Database Layer

### ORM: Drift (SQLite)

**Tables:**

**Tasks**
| Column | Type | Default | Constraints |
|---|---|---|---|
| id | TEXT | (UUID) | Primary key |
| title | TEXT | — | 1-200 chars |
| notes | TEXT | NULL | Nullable |
| dueDate | DATETIME | NULL | Nullable |
| priority | TEXT | 'medium' | Enum: high/medium/low |
| project | TEXT | NULL | Nullable |
| status | TEXT | 'pending' | Enum: pending/inProgress/done/archived |
| createdAt | DATETIME | CURRENT_TIMESTAMP | — |
| completedAt | DATETIME | NULL | Nullable (null = not done) |
| hasReminder | BOOL | false | — |
| reminderTime | TEXT | NULL | Nullable |
| isCalendarEvent | BOOL | false | — |

**CalendarEvents**
| Column | Type | Default |
|---|---|---|
| id | TEXT | (UUID) |
| title | TEXT | 1-200 chars |
| description | TEXT | Nullable |
| startTime | DATETIME | Required |
| endTime | DATETIME | Required |
| color | TEXT | 'blue' |
| taskId | TEXT | Nullable |

**Settings** (key-value store)
| Column | Type |
|---|---|
| key | TEXT |
| value | TEXT |

**Database file:** `getApplicationDocumentsDirectory()/app.sqlite`
**Schema version:** 1
**Execution:** `NativeDatabase.createInBackground(file)`

### DAOs

- `TaskDao` — CRUD operations, filtering by project/priority/status
- `CalendarEventDao` — Calendar event management
- `SettingsDao` — Key-value settings persistence

---

## 8. Notifications

**Package:** `flutter_local_notifications ^19.5.0`

**Android permissions:**
- `POST_NOTIFICATIONS`
- `RECEIVE_BOOT_COMPLETED`
- `SCHEDULE_EXACT_ALARM`
- `USE_EXACT_ALARM`
- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_MICROPHONE`

**Receivers registered:**
- `ScheduledNotificationReceiver` — fires scheduled notifications
- `ScheduledNotificationBootReceiver` — re-schedules after device reboot

**Key capabilities:**
- Schedule exact-time notifications for task reminders
- Survive device reboots (via BOOT_COMPLETED receiver)
- Works with Android 12+ exact alarm restrictions

---

## 9. Test Suite

**Total: 117 tests** — all passing

### Test Files

| File | Coverage |
|---|---|
| `test/core/parser/task_parser_test.dart` | Task parsing: priorities, dates, times, relative time, multi-intent, filler words |
| `test/database/task_dao_test.dart` | Drift DAO CRUD operations |
| `test/integration/task_flow_test.dart` | End-to-end: transcription → parse → save |
| `test/notifications/notification_service_test.dart` | Notification scheduling |
| `test/phase7_test.dart` | Riverpod provider sync overrides |
| `test/screens/record_screen_test.dart` | Recording screen UI |
| `test/services/backup_service_test.dart` | DB backup/restore |
| `test/stt/pipeline_test.dart` | STT pipeline: recording → WAV → whisper |
| `test/stt/whisper_integration_test.dart` | Whisper FFI bindings |
| `test/widget_test.dart` | Basic widget smoke test |
| `test/parser/task_parser_test.dart` | Legacy parser tests |

### Test Configuration

- **Timeout:** 120 seconds per test
- **Riverpod:** Must use synchronous overrides (`overrideWith`, `overrideWithValue`)
- **NO `Future.delayed`** — causes timeout failures
- **Completion fixtures:** Must include `completedAt` timestamps for done tasks
- **Database tests:** Use `AppDatabase.test(executor)` for in-memory testing

### Running Tests

```bash
cd ~/projects/voice_task_app
~/development/flutter/bin/flutter test
```

### Static Analysis

```bash
cd ~/projects/voice_task_app
~/development/flutter/bin/flutter analyze
```
Must return 0 issues.

---

## 10. Known Decisions & Workarounds

### 10.1 Whisper GPU Disabled
`useGpu = false` in `WhisperService.initialize()`. Android GPU drivers are fragmented; CPU-only is slower but stable on all devices.

### 10.2 Task Completion via `completedAt`
The app uses `task.completedAt != null` to determine completion, NOT `task.status == TaskStatus.done`. Test fixtures MUST include `completedAt` timestamps.

### 10.3 Riverpod Test Overrides
- `StateProvider` → `.overrideWith((ref) => value)`
- `StreamProvider` → `.overrideWithValue(AsyncValue.data(value))`
- `FutureProvider` → `.overrideWithValue(AsyncValue.data(value))`
Using `.override(value)` causes type mismatch errors.

### 10.4 `.withValues()` replaces `.withOpacity()`
Current Flutter version deprecated `withOpacity()`. All color opacity uses `.withValues(alpha: X)`.

### 10.5 APK Handler Conflict on Android
Some Android devices register third-party apps (e.g., DeepSeek) as default `.apk` handlers. Users must select **Package Installer** when prompted. Direct download link (`uc?export=download`) bypasses the Google Drive preview UI.

### 10.6 Relative Time Must Parse Before Absolute Time
In the parser pipeline, `_extractRelativeTime()` runs BEFORE absolute date/time regex matching. If reversed, the "in" from "in 10 minutes" could be consumed by date parsing, leaving "10 minutes" unparseable.

### 10.7 `main.dart` Dynamic Routes
The `/preview` route MUST read `settings.arguments` dynamically. Hardcoding a test string ("Sample task for testing") was a bug that caused all recordings to show the same text.

### 10.8 `splitAndParse()` vs `parse()`
`preview_screen.dart` uses `TaskParser.splitAndParse()` (not `parse()`) to handle multi-intent voice input. Single `parse()` only creates one task.

### 10.9 Time Format Flexibility
The time parser handles `1:45pm`, `1.45pm`, `145pm`, `1230pm`, `1 45pm`. The regex captures the digits and manually splits/concatenates with colons for parsing.

### 10.10 JDK Path Required for APK Builds
Gradle will use the system default JDK if `JAVA_HOME` isn't set. The build requires JDK 17 specifically:
```bash
export JAVA_HOME=~/.local/opt/jdk-17.0.2
export PATH=$JAVA_HOME/bin:$PATH
```

---

## 11. Build & Release Process

### Prerequisites
- Flutter SDK 3.27.3 at `~/development/flutter/`
- JDK 17.0.2 at `~/.local/opt/jdk-17.0.2`
- `whisper.cpp` compiled as `libwhisper.so` (bundled in `android/app/src/main/jniLibs/`)

### Build Steps

```bash
cd ~/projects/voice_task_app

# 1. Set JDK environment
export JAVA_HOME=~/.local/opt/jdk-17.0.2
export PATH=$JAVA_HOME/bin:$PATH

# 2. Static analysis (must be 0 issues)
~/development/flutter/bin/flutter analyze

# 3. Run all tests (must all pass)
~/development/flutter/bin/flutter test

# 4. Build release APK
~/development/flutter/bin/flutter build apk --release

# 5. Verify APK
ls -lh build/app/outputs/flutter-apk/app-release.apk
```

### Upload to Google Drive

```bash
python3 ~/.hermes/skills/productivity/google-workspace/scripts/google_drive_upload.py \
  ~/projects/voice_task_app/build/app/outputs/flutter-apk/app-release.apk --public
```

### Direct Download Link Format

```
https://drive.google.com/uc?id=<FILE_ID>&export=download
```

### Versioning

Bump in `pubspec.yaml`:
```yaml
version: 1.0.6+10
#            ^^^^ ^
#            name code
```
Increment `+10` for each APK release.

---

## 12. Troubleshooting Guide

### "flutter test" hangs or times out
- **Cause:** `Future.delayed` in test code, or missing Riverpod provider override
- **Fix:** Replace with synchronous overrides, add `allTasksProvider` override

### "flutter analyze" shows `withOpacity` deprecation
- **Fix:** Replace `.withOpacity(0.5)` with `.withValues(alpha: 0.5)`

### APK won't install on device
- **Cause:** Android opened with wrong app (e.g., DeepSeek)
- **Fix:** Select "Package Installer" when prompted. Use direct download link.

### Whisper transcribes to "[Silent audio]"
- **Cause:** WAV file too small (< 44 bytes) or 0 samples after header skip
- **Fix:** Verify `AudioRecorderService` is actually recording, check microphone permission

### Whisper returns gibberish/wrong language
- **Cause:** Using non-English model, or audio not 16kHz mono 16-bit
- **Fix:** Verify `WavConverter.convertToWhisperFormat()` output matches requirements

### Tasks lose time after editing in preview
- **Cause:** `_EditableTask` not preserving `dueTime` state
- **Fix:** Ensure `dueTime` is part of the editable state and included in the save flow

### Riverpod "Bad state" error in tests
- **Cause:** Provider override using wrong method
- **Fix:** `StateProvider` → `.overrideWith((ref) => value)`, `StreamProvider` → `.overrideWithValue(AsyncValue.data(...))`

### Gradle build fails silently
- **Cause:** Wrong JDK version
- **Fix:** `export JAVA_HOME=~/.local/opt/jdk-17.0.2` before build

### "remind me in X minutes" doesn't set reminder time
- **Cause:** Parser runs absolute time extraction before relative time
- **Fix:** `_extractRelativeTime()` must execute first in `parse()` pipeline

### Regex captures "minute" instead of "minutes"
- **Cause:** Alternation order — shorter pattern matches first
- **Fix:** `minutes|minute` not `minute|minutes` in regex alternation

---

## Appendix: Release History

| Version | Build | Date | Notes |
|---|---|---|---|
| 1.0.6 | +10 | May 26, 2026 | v9 APK: relative time parsing ("in X minutes/hours"), 117/117 tests |
| 1.0.6 | +9 | May 26, 2026 | v8 APK: flexible time parsing (1.45pm, 145pm), APK Drive upload fix |
| — | — | May 26, 2026 | Time preservation in preview UI, Riverpod sync fixes, 82 tests |
| — | — | May 26, 2026 | Calendar screen, notification service, record screen integration |

## Appendix: Git Commit History (Last 5)

```
8167c20 feat: whisper.cpp FFI struct complete (27 fields) + record screen wired to STT pipeline (P5-T33)
3096b6e feat: E2E validation — all 59 tests passing (P4-T32)
0c28a74 feat: record screen with real recording integration (P4-T31) — 5/5 tests
20e814a feat: local notification service with scheduling (P4-T30) — 7/7 tests
37db747 feat: calendar screen with month/week view (P4-T29)
```

---

*This document captures the stable working state as of v1.0.6+10. Any future changes should be noted here with the version/commit that introduced them.*
