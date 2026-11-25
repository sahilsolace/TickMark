# TickMark – Desktop Time Tracking Application

**TickMark** is a clean, minimal, production-ready desktop time-tracking application designed for employees and teams to track, organize, and export time spent on projects and tasks. Built with **Flutter Desktop (Windows)**, **Dart**, and **SQLite**.

---

## 🎨 Design & UI Philosophy

TickMark maintains a clean, modern, and uncluttered desktop interface:
- **Primary Green:** `#087A3D`
- **Light Green Background:** `#E8F7E9`
- **Card Background:** White (`#FFFFFF`) with subtle borders (`#D7EBD9`) and soft elevations.
- **Typography:** Segoe UI with clear hierarchical font weights and high-contrast readable text.
- **Responsive Layout:** Adaptive desktop layout with custom window controls and a draggable navigation header.

---

## 🚀 Key Features

### 1. Top Navigation & Custom Header Bar
- Custom framed/frameless window header with drag-to-move support (`DragToMoveArea`).
- Brand badge with TickMark emblem and desktop indicator.
- Fast access to **Export CSV** and **Settings**.
- Native window control buttons: **Minimize**, **Maximize**, and **Close** with graceful shutdown (automatically pauses and saves active timers before exit).

### 2. Project Management & Selection
- Dropdown selector displaying all active projects.
- One-click **+ Add New Project** dialog to create projects immediately.
- Projects table in SQLite with support for renaming and archiving (archived projects remain in historical timesheets without breaking integrity).
- Default seed projects:
  - `BAU Farm Intelligence`
  - `Bingo Blast`
  - `Flutter Prep`
  - `Solace Super Hero`
  - `Internal Tasks`

### 3. Task Creation & Organization
- Associated with the selected project and current work date.
- Task title/description input with validation.
- **Billable / Non-billable** toggle selector (defaults to **Billable**).
- One-click **Add Task** button with input reset and automatic timer initialization (`00:00:00`).

### 4. Task List & Independent Timers
- Horizontal task cards following the minimal light design:
  - Task number badge (`#1`, `#2`, ...)
  - Task description (supports multi-line and long strings)
  - Associated project badge
  - Billable / Non-billable pill badge
  - Elapsed time display in large monospace `HH:MM:SS`
  - **Play / Resume** button (Green)
  - **Pause** button (Amber)
  - **Stop** button (Neutral Dark)
  - **Delete** button with confirmation dialog
- **Timer Rules:**
  - **Strictly single active timer:** Starting another task automatically pauses the previously running task.
  - **Timestamp-accurate:** Uses `DateTime.now()` differences, ensuring accuracy even when minimized.
  - **Periodic SQLite Sync:** Persists sessions periodically and on pause/stop to prevent data loss.
  - **Crash Recovery:** Startup reconciliation closes dangling sessions if the computer crashed or restarted.

### 5. Date-Wise Time Tracking
- Date navigation bar with:
  - **Previous Day** (`<`)
  - **Formatted Selected Date** (click to open calendar date picker)
  - **Next Day** (`>`)
  - **Today** shortcut button
- **Daily Summary Cards:**
  1. **Total Hours:** Total time tracked on the selected date (`HH:MM:SS` & `Xh Ym`).
  2. **Billable Hours:** Total billable time.
  3. **Non-Billable Hours:** Total non-billable time.
  4. **Total Tasks:** Count of tasks on the selected date.
- Running timers on other dates display a notification banner with a "Go to Date" shortcut.

### 6. Employee Profile & Settings
- Local configuration for:
  - **Employee Email:** (e.g. `employee@company.com`, required for CSV export).
  - **Employee Name:** (optional display name).
- Local storage information:
  - Database path on disk with "Copy Path" and "Open in Explorer" shortcuts.
  - Storage size in KB.
  - Total tasks, sessions, and projects count.

### 7. CSV Export Functionality (Critical)
- Dedicated **Export CSV** dialog with multiple scopes:
  - **Selected Day:** Exports records for the active date (`TickMark_Timesheet_YYYY-MM-DD.csv`).
  - **Custom Date Range:** Select start and end date (`TickMark_Timesheet_START_to_END.csv`).
  - **All Historical Records:** Full history export.
- Native desktop save dialog with user-chosen destination and filename.
- Interactive records preview and count before exporting.
- One-click "Open Folder" upon successful export.
- **Exact CSV Headers in Exact Order:**
  ```csv
  date,employee_email,project_name,task_description,minutes,billable
  ```
- **Example Export:**
  ```csv
  date,employee_email,project_name,task_description,minutes,billable
  2026-11-23,employee@company.com,BAU Farm Intelligence,Fix authentication issue,45,true
  2026-11-23,employee@company.com,BAU Farm Intelligence,Update planting calendar,90,true
  2026-11-23,employee@company.com,Internal Tasks,Team meeting,30,false
  ```
- **Compliance & Compatibility:**
  - RFC 4180 standard escaping for quotes, commas, and newlines.
  - Includes UTF-8 Byte Order Mark (BOM) so **Microsoft Excel** and **Google Sheets** open cleanly without character corruption.
  - Aggregates multiple tracking sessions for the same task on the same date into a single row.

---

## 🗄️ Local SQLite Database Schema

The SQLite database is stored locally in `appSupportDir/TickMark/tickmark.db`.

```sql
-- 1. Employees table
CREATE TABLE employees (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_email TEXT NOT NULL,
  employee_name TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- 2. Projects table
CREATE TABLE projects (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_name TEXT NOT NULL UNIQUE,
  is_archived INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- 3. Tasks table
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL,
  task_description TEXT NOT NULL,
  billable INTEGER NOT NULL DEFAULT 1,
  work_date TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- 4. Time Entries table
CREATE TABLE time_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL,
  employee_id INTEGER NOT NULL,
  start_timestamp TEXT NOT NULL,
  end_timestamp TEXT,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  work_date TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (employee_id) REFERENCES employees(id)
);
```

---

## 🏗️ Architecture & Project Structure

```
lib/
├── database/
│   └── database_helper.dart      # SQLite FFI setup, migrations, CRUD, and crash recovery
├── models/
│   ├── employee_model.dart       # Employee profile model
│   ├── project_model.dart        # Project data model
│   ├── task_model.dart           # Task model with runtime timer state
│   ├── time_entry_model.dart     # Individual time tracking session model
│   ├── daily_summary_model.dart  # Aggregated date totals model
│   └── csv_export_row.dart       # RFC 4180 compliant CSV record model
├── services/
│   ├── time_tracking_service.dart# Timer orchestrator, state management, auto-pause
│   └── csv_export_service.dart   # CSV generator & native file save dialog
├── theme/
│   ├── app_colors.dart           # Soft green palette (#087A3D, #E8F7E9)
│   └── app_theme.dart            # Material 3 light theme definition
├── widgets/
│   ├── custom_header_bar.dart    # Window drag bar, title, minimize/close controls
│   ├── date_navigation_bar.dart  # Date arrows, picker, and Today button
│   ├── daily_summary_cards.dart  # 4-card metric summary (Total, Billable, etc.)
│   ├── task_creation_card.dart   # Project selector, task title, billable toggle
│   ├── task_card_item.dart       # Horizontal task card with play/pause/stop/delete
│   ├── export_csv_dialog.dart    # Multi-scope CSV export dialog with live preview
│   ├── settings_dialog.dart      # Profile, project manager, and storage info
│   └── add_project_dialog.dart   # Quick modal to add new projects
├── screens/
│   └── main_screen.dart          # Master responsive layout
└── main.dart                     # Application entry point, window_manager init
```

---

## 💻 Building and Running

### Prerequisites
- Flutter SDK 3.x+ (Windows desktop enabled)
- Visual Studio 2022 (with Desktop development with C++)

### Run in Debug Mode
```bash
flutter run -d windows
```

### Run Unit & Widget Tests
```bash
flutter test
```

### Static Analysis
```bash
flutter analyze
```

### Build Production Release Binary
```bash
flutter build windows
```
The output executable is generated at:
`build\windows\x64\runner\Release\tickmark.exe`
