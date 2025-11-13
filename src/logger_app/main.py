import os
import sys
import threading
import time
import queue
import subprocess
from dataclasses import dataclass
from datetime import datetime
from typing import Dict, Optional, TextIO

try:
    import psutil
except ImportError as exc:  # pragma: no cover - psutil is required
    raise SystemExit("psutil is required to run this application") from exc

try:
    import keyboard  # type: ignore[import]
except ImportError:
    keyboard = None  # type: ignore[assignment]

from PySide6 import QtCore, QtWidgets


LOG_INTERVAL_SECONDS = 1.0


@dataclass
class ToggleState:
    user_input: bool
    background_processes: bool
    scripts: bool
    resources: bool
    libraries: bool
    databases: bool
    api_calls: bool
    workflows: bool


class LogWriter:
    """Threaded writer that serializes log messages to disk."""

    def __init__(self, path: str) -> None:
        self._path = path
        self._queue: queue.Queue[Optional[str]] = queue.Queue()
        self._thread = threading.Thread(target=self._run, name="LogWriter", daemon=True)
        self._stop_event = threading.Event()
        self._file: Optional[TextIO] = None

    def start(self) -> None:
        os.makedirs(os.path.dirname(self._path) or ".", exist_ok=True)
        self._file = open(self._path, "a", encoding="utf-8")
        self._thread.start()

    def stop(self) -> None:
        self._stop_event.set()
        self._queue.put(None)
        self._thread.join(timeout=5)
        if self._file:
            self._file.flush()
            self._file.close()

    def write(self, message: str) -> None:
        timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        self._queue.put(f"{timestamp} | {message}\n")

    def _run(self) -> None:
        while not self._stop_event.is_set():
            try:
                entry = self._queue.get(timeout=0.5)
            except queue.Empty:
                continue

            if entry is None:
                break

            if self._file:
                self._file.write(entry)
                self._file.flush()


class LoggingManager(QtCore.QObject):
    """Coordinates process execution and logging collectors."""

    status_message = QtCore.Signal(str)
    logging_state_changed = QtCore.Signal(bool)
    process_state_changed = QtCore.Signal(str)

    def __init__(self) -> None:
        super().__init__()
        self._process: Optional[subprocess.Popen[bytes]] = None
        self._psutil_process: Optional[psutil.Process] = None
        self._log_writer: Optional[LogWriter] = None
        self._monitor_thread: Optional[threading.Thread] = None
        self._monitor_stop_event = threading.Event()
        self._toggles: Optional[ToggleState] = None
        self._logging_active = False
        self._user_input_hooked = False
        self._keyboard_hook_handle = None

    @property
    def process_running(self) -> bool:
        return self._process is not None and self._process.poll() is None

    @property
    def logging_active(self) -> bool:
        return self._logging_active

    def launch_executable(self, exe_path: str) -> None:
        if not os.path.isfile(exe_path):
            raise FileNotFoundError(f"Executable not found: {exe_path}")

        if self.process_running:
            raise RuntimeError("Another process is already running.")

        working_dir = os.path.dirname(exe_path) or None
        self._process = subprocess.Popen(
            [exe_path],
            cwd=working_dir,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        self._psutil_process = psutil.Process(self._process.pid)
        try:
            self._psutil_process.cpu_percent(interval=None)
        except Exception:
            pass

        self.process_state_changed.emit("running")
        self.status_message.emit(
            f"Launched executable '{exe_path}' (pid={self._process.pid})."
        )

        threading.Thread(
            target=self._watch_process_exit,
            name="ProcessWatcher",
            daemon=True,
        ).start()

    def _watch_process_exit(self) -> None:
        if self._process is None:
            return
        self._process.wait()
        exit_code = self._process.returncode
        self.status_message.emit(f"Process exited with code {exit_code}.")
        self.process_state_changed.emit("stopped")
        if self._logging_active:
            self.stop_logging()

    def start_logging(self, log_path: str, toggles: ToggleState) -> None:
        if not self.process_running:
            raise RuntimeError("No running process to monitor. Launch the executable first.")

        if self._logging_active:
            self.status_message.emit("Logging is already active.")
            return

        self._monitor_stop_event.clear()
        self._toggles = toggles
        self._log_writer = LogWriter(log_path)
        self._log_writer.start()
        self._log_writer.write("=== Logging session started ===")
        self._report_configuration(log_path, toggles)

        if toggles.user_input:
            self._start_user_input_hook()

        self._monitor_thread = threading.Thread(
            target=self._monitor_loop,
            name="ProcessMonitor",
            daemon=True,
        )
        self._monitor_thread.start()
        self._logging_active = True
        self.logging_state_changed.emit(True)
        self.status_message.emit("Logging started.")

    def stop_logging(self) -> None:
        if not self._logging_active:
            self.status_message.emit("Logging is not active.")
            return

        self._monitor_stop_event.set()
        if self._monitor_thread and self._monitor_thread.is_alive():
            self._monitor_thread.join(timeout=5)

        if self._toggles and self._toggles.user_input:
            self._stop_user_input_hook()

        if self._log_writer:
            self._log_writer.write("=== Logging session stopped ===")
            self._log_writer.stop()
            self._log_writer = None

        self._logging_active = False
        self.logging_state_changed.emit(False)
        self.status_message.emit("Logging stopped.")

    def _monitor_loop(self) -> None:
        if not self._psutil_process or not self._toggles or not self._log_writer:
            return

        last_library_snapshot: set[str] = set()
        last_child_snapshot: set[int] = set()

        while not self._monitor_stop_event.is_set():
            if not self.process_running:
                self._log_writer.write("Process is no longer running.")
                break

            try:
                ps_proc = self._psutil_process
                cpu_percent = ps_proc.cpu_percent(interval=None)
                memory_info = ps_proc.memory_info()
                io_counters = ps_proc.io_counters()
            except psutil.Error as err:
                self._log_writer.write(f"[ERROR] psutil failure: {err}")
                break

            if self._toggles.resources:
                self._log_writer.write(
                    "[RESOURCE] CPU %.2f%% | RSS %.2f MB | VMS %.2f MB | "
                    "Read %.2f MB | Write %.2f MB"
                    % (
                        cpu_percent,
                        memory_info.rss / (1024 * 1024),
                        memory_info.vms / (1024 * 1024),
                        io_counters.read_bytes / (1024 * 1024),
                        io_counters.write_bytes / (1024 * 1024),
                    )
                )

            if self._toggles.background_processes or self._toggles.scripts or self._toggles.workflows:
                children = ps_proc.children(recursive=True)
                child_ids = {child.pid for child in children}
                new_children = child_ids - last_child_snapshot
                terminated_children = last_child_snapshot - child_ids
                last_child_snapshot = child_ids

                if new_children and self._log_writer:
                    for child in children:
                        if child.pid in new_children:
                            cmdline = " ".join(child.cmdline())
                            self._log_writer.write(
                                f"[PROCESS] New child pid={child.pid} name='{child.name()}' cmd='{cmdline}'"
                            )
                            if self._toggles.scripts and any(
                                ext in cmdline.lower() for ext in (".py", ".bat", ".cmd", ".ps1")
                            ):
                                self._log_writer.write(
                                    f"[SCRIPT] Script-like child process detected pid={child.pid} cmd='{cmdline}'"
                                )

                if terminated_children:
                    for pid in terminated_children:
                        self._log_writer.write(f"[PROCESS] Child pid={pid} terminated.")

            if self._toggles.libraries:
                try:
                    mapped_files = ps_proc.memory_maps()
                    current_libraries = {
                        os.path.normpath(m.path) for m in mapped_files if m.path
                    }
                    new_libs = current_libraries - last_library_snapshot
                    removed_libs = last_library_snapshot - current_libraries
                    if new_libs:
                        for lib in sorted(new_libs):
                            self._log_writer.write(f"[LIBRARY] Loaded: {lib}")
                    if removed_libs:
                        for lib in sorted(removed_libs):
                            self._log_writer.write(f"[LIBRARY] Unloaded: {lib}")
                    last_library_snapshot = current_libraries
                except (psutil.AccessDenied, psutil.NoSuchProcess):
                    pass
                except Exception as err:
                    self._log_writer.write(f"[LIBRARY][ERROR] {err}")

            if self._toggles.api_calls or self._toggles.databases or self._toggles.workflows:
                try:
                    connections = ps_proc.connections(kind="inet")
                except psutil.Error as err:
                    self._log_writer.write(f"[NETWORK][ERROR] {err}")
                    connections = []

                for conn in connections:
                    laddr = f"{conn.laddr.ip}:{conn.laddr.port}" if conn.laddr else "?:?"
                    raddr = f"{conn.raddr.ip}:{conn.raddr.port}" if conn.raddr else "?:?"
                    status = conn.status
                    family = conn.family.name if hasattr(conn.family, "name") else str(conn.family)
                    type_ = conn.type.name if hasattr(conn.type, "name") else str(conn.type)
                    self._log_writer.write(
                        f"[NETWORK] fd={conn.fd} family={family} type={type_} local={laddr} remote={raddr} status={status}"
                    )

                    if self._toggles.databases and conn.raddr:
                        if conn.raddr.port in {1433, 3306, 5432, 1521, 27017, 6379}:
                            self._log_writer.write(
                                f"[DATABASE] Potential DB connection remote={raddr} status={status}"
                            )

                    if self._toggles.api_calls and conn.raddr:
                        self._log_writer.write(
                            f"[API] Remote endpoint contacted {raddr} (status={status})"
                        )

            if self._toggles.resources or self._toggles.workflows:
                try:
                    num_threads = ps_proc.num_threads()
                    ctx_switches = ps_proc.num_ctx_switches()
                    open_files = ps_proc.open_files()
                except psutil.Error:
                    num_threads = None
                    ctx_switches = None
                    open_files = []

                if num_threads is not None:
                    self._log_writer.write(
                        f"[WORKFLOW] Threads={num_threads} VoluntaryCS={getattr(ctx_switches, 'voluntary', 'n/a')} "
                        f"InvoluntaryCS={getattr(ctx_switches, 'involuntary', 'n/a')}"
                    )

                if open_files:
                    for opened in open_files:
                        self._log_writer.write(
                            f"[RESOURCE] Open file fd={opened.fd} path='{opened.path}' mode={opened.mode}"
                        )

            time.sleep(LOG_INTERVAL_SECONDS)

    def _report_configuration(self, log_path: str, toggles: ToggleState) -> None:
        if not self._log_writer:
            return
        self._log_writer.write(f"[CONFIG] Log path: {os.path.abspath(log_path)}")
        for field in toggles.__dataclass_fields__:
            enabled = getattr(toggles, field)
            self._log_writer.write(f"[CONFIG] {field.replace('_', ' ').title()}: {enabled}")

    def _start_user_input_hook(self) -> None:
        if keyboard is None:
            self.status_message.emit(
                "Keyboard package unavailable; user input logging disabled."
            )
            return

        if self._user_input_hooked:
            return

        def _keyboard_callback(event: "keyboard.KeyboardEvent") -> None:
            if not self._logging_active or not self._log_writer:
                return
            self._log_writer.write(
                f"[INPUT] Key {event.event_type} name={event.name} scan_code={event.scan_code}"
            )

        try:
            self._keyboard_hook_handle = keyboard.hook(_keyboard_callback, suppress=False)
            self._user_input_hooked = True
            self.status_message.emit("User input logging enabled.")
        except Exception as err:
            self.status_message.emit(f"Failed to hook keyboard: {err}")

    def _stop_user_input_hook(self) -> None:
        if keyboard is None or not self._user_input_hooked:
            return
        try:
            if self._keyboard_hook_handle:
                keyboard.unhook(self._keyboard_hook_handle)
        finally:
            self._user_input_hooked = False
            self._keyboard_hook_handle = None


class MainWindow(QtWidgets.QWidget):
    """Main GUI entry point."""

    START_HOTKEY = "ctrl+alt+f9"
    STOP_HOTKEY = "ctrl+alt+f10"

    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Executable Instrumentation Logger")
        self.resize(780, 520)

        self._manager = LoggingManager()
        self._manager.status_message.connect(self._append_status)
        self._manager.logging_state_changed.connect(self._update_logging_buttons)
        self._manager.process_state_changed.connect(self._update_process_state)

        self._build_ui()
        self._register_hotkeys()

    def _build_ui(self) -> None:
        layout = QtWidgets.QVBoxLayout(self)

        exe_layout = QtWidgets.QHBoxLayout()
        self.exe_path_input = QtWidgets.QLineEdit()
        self.exe_path_input.setPlaceholderText("Path to executable (.exe)")
        exe_browse = QtWidgets.QPushButton("Browse…")
        exe_browse.clicked.connect(self._browse_executable)
        exe_layout.addWidget(QtWidgets.QLabel("Executable:"))
        exe_layout.addWidget(self.exe_path_input)
        exe_layout.addWidget(exe_browse)

        log_layout = QtWidgets.QHBoxLayout()
        self.log_path_input = QtWidgets.QLineEdit()
        self.log_path_input.setPlaceholderText("Path for output log file")
        log_browse = QtWidgets.QPushButton("Browse…")
        log_browse.clicked.connect(self._browse_log_file)
        log_layout.addWidget(QtWidgets.QLabel("Log File:"))
        log_layout.addWidget(self.log_path_input)
        log_layout.addWidget(log_browse)

        layout.addLayout(exe_layout)
        layout.addLayout(log_layout)

        toggles_group = QtWidgets.QGroupBox("Data captured")
        toggles_layout = QtWidgets.QGridLayout()
        self.toggle_inputs: Dict[str, QtWidgets.QCheckBox] = {}
        toggle_definitions = [
            ("user_input", "User Input Events"),
            ("background_processes", "Background Processes"),
            ("scripts", "Scripts & Command Invocations"),
            ("resources", "Resource Usage (CPU, Memory, IO)"),
            ("libraries", "Libraries / Modules Loaded"),
            ("databases", "Database Connections"),
            ("api_calls", "API Calls / Network Activity"),
            ("workflows", "Threads, Files & Workflow Events"),
        ]
        for row, (key, label) in enumerate(toggle_definitions):
            checkbox = QtWidgets.QCheckBox(label)
            checkbox.setChecked(True if key in {"resources", "background_processes"} else False)
            self.toggle_inputs[key] = checkbox
            toggles_layout.addWidget(checkbox, row // 2, row % 2)

        toggles_group.setLayout(toggles_layout)
        layout.addWidget(toggles_group)

        actions_layout = QtWidgets.QHBoxLayout()
        self.run_button = QtWidgets.QPushButton("Run .exe")
        self.run_button.clicked.connect(self._run_executable)
        self.start_button = QtWidgets.QPushButton("Start Logging")
        self.start_button.clicked.connect(self._start_logging)
        self.stop_button = QtWidgets.QPushButton("Stop Logging")
        self.stop_button.clicked.connect(self._stop_logging)
        self.stop_button.setEnabled(False)
        actions_layout.addWidget(self.run_button)
        actions_layout.addWidget(self.start_button)
        actions_layout.addWidget(self.stop_button)
        layout.addLayout(actions_layout)

        hotkey_label = QtWidgets.QLabel(
            f"Keyboard shortcuts — Start: {self.START_HOTKEY}  |  Stop: {self.STOP_HOTKEY}"
        )
        hotkey_label.setAlignment(QtCore.Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(hotkey_label)

        self.status_display = QtWidgets.QPlainTextEdit()
        self.status_display.setReadOnly(True)
        self.status_display.setPlaceholderText("Application status messages will appear here.")
        layout.addWidget(self.status_display, stretch=1)

        self.status_bar = QtWidgets.QLabel("Idle.")
        self.status_bar.setAlignment(QtCore.Qt.AlignmentFlag.AlignRight)
        layout.addWidget(self.status_bar)

    def _register_hotkeys(self) -> None:
        if keyboard is None:
            self._append_status(
                "keyboard package unavailable; global hotkeys are disabled."
            )
            return

        try:
            keyboard.add_hotkey(self.START_HOTKEY, self._hotkey_start)
            keyboard.add_hotkey(self.STOP_HOTKEY, self._hotkey_stop)
            self._append_status(
                f"Registered hotkeys: start [{self.START_HOTKEY}], stop [{self.STOP_HOTKEY}]"
            )
        except Exception as err:
            self._append_status(f"Failed to register hotkeys: {err}")

    def _hotkey_start(self) -> None:
        QtCore.QTimer.singleShot(0, self._start_logging)

    def _hotkey_stop(self) -> None:
        QtCore.QTimer.singleShot(0, self._stop_logging)

    def _browse_executable(self) -> None:
        path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self,
            "Select executable",
            "",
            "Executable Files (*.exe);;All Files (*)",
        )
        if path:
            self.exe_path_input.setText(path)

    def _browse_log_file(self) -> None:
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self,
            "Select log file",
            "",
            "Log Files (*.log);;Text Files (*.txt);;All Files (*)",
        )
        if path:
            self.log_path_input.setText(path)

    def _run_executable(self) -> None:
        exe_path = self.exe_path_input.text().strip()
        if not exe_path:
            self._append_status("Please provide an executable path.")
            return
        try:
            self._manager.launch_executable(exe_path)
        except Exception as err:
            self._append_status(f"Failed to launch executable: {err}")

    def _collect_toggles(self) -> ToggleState:
        return ToggleState(
            user_input=self.toggle_inputs["user_input"].isChecked(),
            background_processes=self.toggle_inputs["background_processes"].isChecked(),
            scripts=self.toggle_inputs["scripts"].isChecked(),
            resources=self.toggle_inputs["resources"].isChecked(),
            libraries=self.toggle_inputs["libraries"].isChecked(),
            databases=self.toggle_inputs["databases"].isChecked(),
            api_calls=self.toggle_inputs["api_calls"].isChecked(),
            workflows=self.toggle_inputs["workflows"].isChecked(),
        )

    def _start_logging(self) -> None:
        log_path = self.log_path_input.text().strip()
        if not log_path:
            self._append_status("Please provide a log file path.")
            return
        toggles = self._collect_toggles()
        if not any(toggles.__dict__.values()):
            self._append_status("Enable at least one data category before logging.")
            return
        try:
            self._manager.start_logging(log_path, toggles)
        except Exception as err:
            self._append_status(f"Unable to start logging: {err}")

    def _stop_logging(self) -> None:
        try:
            self._manager.stop_logging()
        except Exception as err:
            self._append_status(f"Unable to stop logging: {err}")

    @QtCore.Slot(str)
    def _append_status(self, message: str) -> None:
        timestamp = datetime.utcnow().strftime("%H:%M:%S")
        self.status_display.appendPlainText(f"[{timestamp}] {message}")
        self.status_display.verticalScrollBar().setValue(
            self.status_display.verticalScrollBar().maximum()
        )

    @QtCore.Slot(bool)
    def _update_logging_buttons(self, logging: bool) -> None:
        self.start_button.setEnabled(not logging)
        self.stop_button.setEnabled(logging)
        if logging:
            self.status_bar.setText("Logging active")
        else:
            state = "Process running" if self._manager.process_running else "Idle"
            self.status_bar.setText(state)

    @QtCore.Slot(str)
    def _update_process_state(self, state: str) -> None:
        if state == "running":
            self.status_bar.setText("Process running")
            self.run_button.setEnabled(False)
        else:
            self.status_bar.setText("Idle")
            self.run_button.setEnabled(True)


def main() -> None:
    app = QtWidgets.QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
