# Executable Activity Logger

A desktop utility that launches a Windows executable and captures a detailed, timestamped trail of everything the program does while you interact with it. The tool is designed for debugging and exploratory testing of executables that you own. It combines a GUI front end with a collection of background watchers that log user input, process behaviour, filesystem usage, module loads, and network traffic into a plain-text report.

> **Scope reminder:** This project targets local, developer-owned `.exe` files on Windows. Administrative privileges may be required for several capture features (global input hooks, process/file inspection, and the optional keyboard macros).

## Features

- Launch any `.exe` (and optional command-line arguments) directly from the UI and begin logging instantly.
- Toggle individual data domains before you start a session:
  - `User input` — global keyboard + mouse events.
  - `Processes & child workflows` — process tree changes, child commands, lifecycle.
  - `Resource usage` — CPU %, memory, thread counts, handle counts, basic IO counters.
  - `File activity` — files opened/closed by the target process.
  - `Libraries/modules` — DLLs and other binaries mapped into the process.
  - `Network/API/DB activity` — inbound/outbound connections with light classification (HTTP/S, DB ports, etc.).
- Plain-text log file with precise timestamps and rich metadata for every captured event.
- Global hotkeys (`Ctrl+Alt+Shift+F5` / `Ctrl+Alt+Shift+F6`) to start/stop logging from the keyboard.
- Optional checkbox to terminate the target process automatically when you stop logging.
- Status console in the GUI shows high-level progress and errors in real time.

## Installation

1. **Install Python 3.10 or newer** on the Windows machine where you will run the logger.
2. Clone or copy this project to that machine.
3. (Recommended) Create and activate a virtual environment.
4. Install dependencies:

   ```bash
   pip install -r requirements.txt
   ```

   The `keyboard` and `pynput` packages install low-level hooks. On Windows you may need to run the install and the application from an elevated prompt.

5. If you plan to package or install the app, you can also use the `pyproject.toml` metadata:

   ```bash
   pip install .
   ```

## Running the Logger

```bash
python -m application_logger.main
```

If you installed the project (`pip install .`), an entry point named `exe-activity-logger` is also available:

```bash
exe-activity-logger
```

## Using the GUI

1. **Select the target executable**: Browse to your `.exe`, `.cmd`, `.bat`, or `.ps1` file. Optionally enter additional arguments.
2. **Choose an output location**: Provide a log file path or a directory. If the path is a directory (or left blank), a timestamped log file is generated automatically.
3. **Pick capture options**: Enable or disable any combination of data domains before you start.
4. **Start logging**: Click *Run & Log* (or press the start macro). The tool launches the executable and spawns all requested watchers.
5. **Stop logging**: Click *Stop Logging* (or use the stop macro). Optionally terminate the target process when stopping by enabling the checkbox.
6. **Review the log**: Open the generated `.log` file in any text editor. Each line includes an ISO-8601 timestamp, the watcher name, a subtype, a message, and key metadata fields.

## Keyboard Macros

- Start logging: `Ctrl+Alt+Shift+F5`
- Stop logging: `Ctrl+Alt+Shift+F6`

Macros are optional. They require the `keyboard` package and usually administrative rights on Windows because they register global hotkeys. When hotkeys cannot be registered, the GUI will display a status message and continue to function normally.

## Captured Data Details

| Watcher | Example events | Notes |
| --- | --- | --- |
| `user_input` | Key presses/releases; mouse clicks & scrolls. | Uses `pynput`. Continuous mouse movement is intentionally ignored to keep the log concise. |
| `process` | Start/stop of child processes, CPU %, RSS, handles, IO counters. | Requires access to the process. Some statistics may produce `AccessDenied` unless run elevated. |
| `file_activity` | Files the executable opens or closes. | Relies on `psutil.Process.open_files()`. On Windows this may require admin rights and works best when the target is owned by the same user. |
| `modules` | DLLs and other modules mapped into process memory. | Uses `psutil.Process.memory_maps()`. Frequent polling (3s default) to detect changes. |
| `network` | TCP/UDP connections, remote endpoints, port-based classification (API vs database). | Detects common DB ports (1433, 1521, 27017, 3306, 5432, 6379) and HTTP ports (80, 443, 8080, 8443). |

Each watcher reports failures (e.g., missing privileges or unavailable APIs) into the log so that gaps in coverage are visible.

## Limitations & Notes

- **Privileges:** Low-level hooks and process inspection often need administrator or elevated privileges on Windows. Without them, certain watchers will report access errors and skip events.
- **API/system call tracing:** The utility does **not** provide deep API interception (e.g., function-level call stacks). It surfaces observable effects—processes, files, modules, and connections—rather than internal call graphs.
- **Performance impact:** Polling watchers run every 1–3 seconds. For high-frequency tracing you may need to tune the polling interval in the source code.
- **Log volume:** Capturing user input can generate large logs, especially during intensive testing. Disable any categories that are not relevant to a session.
- **Windows focus:** While the code is written in Python and can technically run elsewhere, the intended environment is Windows. Some watchers rely on Windows-only behaviours and will be degraded or unavailable on other OSes.
- **Security:** The logger stores raw key presses and file paths. Treat the generated logs as sensitive artefacts.

## Extending the Logger

- Adjust polling intervals for watchers inside `src/application_logger/watchers/`.
- Add new watchers by subclassing `BaseWatcher` and registering them in `LogManager._instantiate_watchers`.
- Enhance correlation logic by post-processing the log (e.g., grouping events by timestamp or user input sequence).

## Troubleshooting

- **Hotkeys not working**: Confirm the application is running with sufficient privileges and `keyboard` is installed. The status console will mention if registration failed.
- **“Access denied” in logs**: Relaunch the logger as Administrator. Some system-protected processes cannot be inspected even with elevation.
- **No log created**: Ensure the log directory exists or that you have write permissions. The GUI will report failures when preparing the output file.

---

Developed for debugging and audit trails of your own executables. Adapt as needed for your testing workflow.
