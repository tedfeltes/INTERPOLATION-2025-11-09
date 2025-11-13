# Application Execution & Process Logger

This project provides a desktop application that launches a Windows executable while capturing a detailed trail of the activity it generates. It is intended for local debugging of `.exe` files you own during manual testing sessions.

## Features

- **Run & monitor a target executable** with a single click.
- **Plain-text log output** that chronicles events in chronological order.
- **Toggleable data sources** covering:
  - User input (keyboard and mouse).
  - CPU / memory / IO metrics.
  - Child/background processes.
  - File and resource handles (including scripts and database files).
  - Loaded modules and libraries.
  - Network sockets representing API calls.
- **Global hotkeys** (`Ctrl+Alt+F9` to start, `Ctrl+Alt+F10` to stop).
- **Live status panel** showing progress and process output (stdout/stderr).

## Requirements

- Windows 10/11 recommended (the tool targets `.exe` files and relies on Windows-compatible hooks).
- Python 3.10+.
- The dependencies listed in `requirements.txt`:
  ```bash
  pip install -r requirements.txt
  ```

> **Note:** Global input hooks (`pynput`, `keyboard`) may require running the Python process with elevated privileges, depending on your OS security settings.

## Running the application

```bash
python -m app.main
```

On launch you can:

1. Select the target `.exe`.
2. Choose where the log file should be written (defaults to a timestamped file in the working directory).
3. Enable/disable the data streams you want to capture.
4. Click **Run & Start Logging** (or press `Ctrl+Alt+F9`) to begin.

Logs are written incrementally. Stopping the session (button or `Ctrl+Alt+F10`) flushes and closes the log file. If the target process is still running when you stop logging, the app gives you the option to terminate it.

## Log format

Each entry is timestamped (UTC) and grouped by category. Example excerpt:

```
[2025-11-13 18:22:40.125643] [SYSTEM] Log session started
[2025-11-13 18:22:40.214009] [PROCESS] Target executable launched.
    Details: {"pid": 1234, "exe": "C:\\path\\app.exe", "cwd": "C:\\path"}
[2025-11-13 18:22:41.003122] [USER_INPUT] Key press detected.
    Details: {"key": "space"}
[2025-11-13 18:22:41.521090] [NETWORK_ACTIVITY] Network connection observed.
    Details: {"pid": 1234, "local": "127.0.0.1:53243", "remote": "api.example.com:443", "status": "ESTABLISHED"}
```

## Limitations & Notes

- The user input monitor and hotkeys rely on system-wide hooks. Some sandboxed or high-security environments block them.
- Capturing modules (`memory_maps`) and open files requires process inspection privileges; you may need to run as Administrator.
- Network monitoring relies on `psutil` and reports socket endpoints rather than high-level API names.
- Database and script detections are heuristic (file extensions).
- The app currently targets a single running process at a time; start a new session for each run you want to profile.

## Development

The core modules reside in `app/`:

- `app/main.py` – GUI entry point and orchestration.
- `app/logger.py` – Thread-safe log writer.
- `app/monitor_manager.py` – Creates and manages monitors based on user options.
- `app/monitors/` – Monitoring implementations (user input, process activity).

You can validate syntax with:

```bash
python3 -m py_compile $(find app -name "*.py")
```

Feel free to extend the monitors folder with additional domain-specific observers (e.g., Windows Event Log integration) if your debugging workflow requires more depth.

