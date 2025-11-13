# Executable Instrumentation Logger

This project provides a desktop application for instrumenting and logging behaviour of Windows `.exe` binaries that you own. It launches the selected executable, attaches a set of configurable monitors, and records the resulting activity in a plaintext log file suitable for debugging and audit trails.

> ⚠️ **Disclaimer:** The monitors in this tool rely on user-mode APIs (`psutil`, `pynput`, `keyboard`, ETW) and therefore require administrator privileges on Windows for full coverage (especially for global input capture and ETW traces). Use exclusively on binaries you created and control, in accordance with local laws and policies.

## Features

- Launch an executable and capture:
  - Keyboard and mouse input (global, optional)
  - Background process tree changes, child process creation/exit, thread snapshots
  - Files and scripts accessed
  - Loaded DLLs/modules
  - Network sockets and remote endpoints
  - Resource usage (CPU, memory, IO, handles)
  - Database-flavoured network connections (common ports)
  - Optional Win32 API call tracing via ETW (Windows-only, requires `python-etw`)
- GUI controls for toggling each monitor before launch.
- Choose the executable path and the destination log file.
- Global hotkeys (default `Ctrl+Shift+Alt+S` to start logging, `Ctrl+Shift+Alt+E` to stop).
- Log viewer pane updates live while logging and writes to the text file with timestamps.
- "Terminate process" control, automatic cleanup when the executable exits.

## Project Layout

```
src/
  gui/            # PySide6 GUI (main window, run loop)
  monitors/       # Monitoring implementations (process, file, network, etc.)
  services/       # Logging controller and global hotkey management
requirements.txt  # Python runtime dependencies
README.md
```

## Getting Started

1. **Install dependencies**

   ```bash
   python -m venv .venv
   source .venv/bin/activate        # Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

   Optional (Windows-only, for API call tracing):

   ```powershell
   pip install python-etw
   ```

2. **Run the application**

   ```bash
   # Ensure the src/ directory is on PYTHONPATH
   PYTHONPATH=src python -m gui.main_window
   ```

   On Windows PowerShell:

   ```powershell
   $env:PYTHONPATH="src"
   python -m gui.main_window
   ```

3. **Use the GUI**
   - Set the path to your `.exe`.
   - Choose a destination log file (or accept the auto-generated default).
   - Enable the data categories you want.
   - Click **Run & Attach**; the executable launches and monitors become ready.
   - Press `Ctrl+Shift+Alt+S` (or the **Start Logging** button) to begin recording.
   - Press `Ctrl+Shift+Alt+E` (or **Stop Logging**) to pause.
   - Inspect the live log pane or open the log file after the session.

## Hotkeys & Controls

- **Start Logging:** `Ctrl+Shift+Alt+S`
- **Stop Logging:** `Ctrl+Shift+Alt+E`
- Buttons are provided for environments where global hotkeys are unavailable (e.g., insufficient permissions).

## Log File Format

- Timestamped lines (`YYYY-MM-DD HH:MM:SS.mmm`) with category tags such as `[Process]`, `[File]`, `[Network]`, `[Resource]`, `[Input]`, `[Database]`, `[API]`.
- Session prologue/epilogue markers: `# Log session started ...` / `# Log session closed ...`.

Example snippet:

```
2025-11-13 10:45:31.512 [Process] Child started: pid=8124, name=python.exe, cmdline=python.exe worker.py
2025-11-13 10:45:32.101 [Resource] cpu=18.4% rss=12021760 vms=25493504 io_read=4096 io_write=0 handles=134 threads=8
2025-11-13 10:45:34.220 [Network] pid=8124 fd=368 status=ESTABLISHED local=myhost:54321 remote=db.internal:5432
```

## Notes & Limitations

- **Administrator rights:** Windows global input hooks (`pynput`, `keyboard`) may require elevated privileges.
- **ETW tracing:** API call logging is optional. Install `python-etw` and run the program from an elevated terminal. ETW sessions can generate high event volumes; enable only when needed.
- **Permissions:** Access to process internals, open file handles, and network sockets may require running the GUI with sufficient privileges.
- **Performance impact:** Polling monitors intentionally use conservative intervals, but capturing many categories simultaneously still introduces overhead.
- **Non-Windows environments:** The GUI runs on Linux/macOS for development, but launching and instrumenting Windows `.exe` files requires running the tool on Windows.

## Extending

- Additional monitors can be added under `src/monitors/` by subclassing `BaseMonitor` or wiring event-driven listeners.
- The GUI uses dependency injection via `LoggingController`; new monitor toggles require updating `MonitorConfig`, the toggle map in `MainWindow`, and the monitor factory in `LoggingController`.

## Troubleshooting

- **Hotkeys not working:** Ensure the process is run as administrator on Windows. Verify the `keyboard` package is installed and no other software is intercepting the combos.
- **No API logs:** Install `python-etw` and rerun elevated. Confirm the `Win32` provider is enabled in Event Viewer.
- **Permissions errors (`AccessDenied`):** Run the GUI with admin privileges or adjust Windows security policies.
- **Executable closes immediately:** Check the exit code in the log pane. You can relaunch after adjusting command-line arguments or environment variables in your binary.
