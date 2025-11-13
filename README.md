# Executable Instrumentation Logger

This project provides a desktop application for Windows that helps you instrument and debug `.exe` applications that you own by capturing and correlating runtime activity with user-triggered events. The tool launches a selected executable, records telemetry depending on the categories you enable, and writes a rich plain-text log for review.

## Features

- Launch any user-specified `.exe` from the GUI.
- Toggle granular logging categories: user input, background processes, scripts, resource usage, loaded libraries, database activity, API calls/network activity, and other workflow indicators (threads, open files).
- Configure the log destination through a file picker or direct text input.
- Global keyboard shortcuts (`Ctrl` + `Alt` + `F9` to start, `Ctrl` + `Alt` + `F10` to stop) to control logging without leaving your test environment.
- Structured plain-text log outlining how user input relates to downstream process behaviour.

## Getting Started

> **Prerequisites**
>
> - Windows 10/11 with Python 3.10+ installed.
> - Administrative privileges are often required for global keyboard hooks and process inspection.
> - The monitored executable should be created and owned by you, and you should have permission to inspect it.

1. Create and activate a virtual environment.
   ```bash
   python -m venv .venv
   .venv\Scripts\activate
   ```
2. Install dependencies.
   ```bash
   pip install -r requirements.txt
   ```
3. Launch the GUI (from the project root).
   ```bash
   python src/logger_app/main.py
   ```

## Usage

1. **Select the executable**: Browse to the `.exe` you want to test.
2. **Choose a log file**: Pick an existing file or supply a new path; the app creates folders as needed.
3. **Enable categories**: Activate the checkboxes that match the telemetry you want to capture.
4. **Run**: Click `Run .exe` to start the process under observation.
5. **Start logging**: Use the `Start Logging` button or the `Ctrl+Alt+F9` macro. Stop logging with `Ctrl+Alt+F10` or the corresponding button.
6. Inspect the generated log when finished.

While logging, the application samples the target process roughly every second and records:

- CPU, memory, IO usage, open files, thread counts.
- Child processes and script-like invocations.
- Loaded DLLs/modules.
- Network connections and potential database endpoints.
- Global keyboard input (key names and scan codes) if enabled.

## Notes & Limitations

- The tool leverages user-mode APIs (`psutil`, global keyboard hooks). It does **not** provide low-level kernel tracing or packet inspection.
- Logging user input relies on the `keyboard` package which requires elevated privileges and is Windows-only. If the hook fails, an explicit status message is shown and logging continues for other categories.
- Library enumeration uses `memory_maps()`, which is best-effort and may omit modules if access is denied.
- Database/API detection is heuristic, based on remote ports of active TCP connections. Custom protocols may require manual interpretation.
- File system activity is limited to open file descriptors rather than full read/write auditing.
- Some metrics incur overhead; consider disabling unused categories to reduce noise.

## Project Structure

```
src/
└── logger_app/
    ├── __init__.py
    └── main.py
```

Run `python -m logger_app` to exercise the GUI from the project root.

## Development Tips

- On Windows, run your terminal as Administrator before starting the GUI to ensure keyboard hooks succeed.
- Adjust `LOG_INTERVAL_SECONDS` in `src/logger_app/main.py` if you need finer or coarser sampling.
- Extend `_monitor_loop` within `LoggingManager` to capture additional telemetry specific to your workflows.

## License

This project is provided as-is for internal testing. Review and adapt it to your compliance requirements before use in production environments.
