"""
Entry point for the application execution and process logger GUI.
"""

from __future__ import annotations

import os
import subprocess
import sys
import threading
from datetime import datetime
from pathlib import Path
from typing import Optional

from PySide6 import QtCore, QtGui, QtWidgets

try:
    import keyboard as keyboard_lib
except Exception:  # pragma: no cover - keyboard may be unavailable on some OSes
    keyboard_lib = None  # type: ignore

from app.logger import log_manager
from app.monitor_manager import LogOptions, MonitorManager


HOTKEY_START = "ctrl+alt+f9"
HOTKEY_STOP = "ctrl+alt+f10"


class MainWindow(QtWidgets.QMainWindow):
    """Primary window containing configuration controls and runtime status."""

    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Application Execution & Process Logger")
        self.resize(900, 600)

        self._monitor_manager = MonitorManager(log_manager)
        self._process: Optional[subprocess.Popen] = None
        self._poll_timer = QtCore.QTimer(self)
        self._poll_timer.setInterval(1000)
        self._poll_timer.timeout.connect(self._poll_process_state)
        self._logging_active = False
        self._hotkeys_registered = False
        self._hotkey_start_id: Optional[int] = None
        self._hotkey_stop_id: Optional[int] = None

        self._build_ui()
        self._register_hotkeys()

    # --- UI construction -------------------------------------------------

    def _build_ui(self) -> None:
        central = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(central)
        layout.setSpacing(12)

        layout.addWidget(self._build_paths_section())
        layout.addWidget(self._build_toggle_section())
        layout.addWidget(self._build_controls_section())
        layout.addWidget(self._build_status_section(), stretch=1)

        self.setCentralWidget(central)

    def _build_paths_section(self) -> QtWidgets.QGroupBox:
        box = QtWidgets.QGroupBox("Paths")
        form = QtWidgets.QFormLayout(box)

        # Executable path input
        self.exe_path_edit = QtWidgets.QLineEdit()
        exe_browse = QtWidgets.QPushButton("Browse…")
        exe_browse.clicked.connect(self._choose_executable)
        exe_row = QtWidgets.QHBoxLayout()
        exe_row.addWidget(self.exe_path_edit)
        exe_row.addWidget(exe_browse)
        form.addRow("Target executable (.exe):", self._wrap_with_widget(exe_row))

        # Log file path input
        self.log_path_edit = QtWidgets.QLineEdit()
        default_log_name = f"app_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        default_path = Path.cwd() / default_log_name
        self.log_path_edit.setText(str(default_path))
        log_browse = QtWidgets.QPushButton("Browse…")
        log_browse.clicked.connect(self._choose_log_file)
        log_row = QtWidgets.QHBoxLayout()
        log_row.addWidget(self.log_path_edit)
        log_row.addWidget(log_browse)
        form.addRow("Output log file:", self._wrap_with_widget(log_row))

        return box

    def _build_toggle_section(self) -> QtWidgets.QGroupBox:
        box = QtWidgets.QGroupBox("Data Streams to Log")
        grid = QtWidgets.QGridLayout(box)
        grid.setHorizontalSpacing(24)
        grid.setVerticalSpacing(8)

        self.check_user_input = QtWidgets.QCheckBox("User Input (keyboard & mouse)")
        self.check_process_stats = QtWidgets.QCheckBox("Resource Usage (CPU / Memory)")
        self.check_child_processes = QtWidgets.QCheckBox("Background / Child Processes")
        self.check_files_resources = QtWidgets.QCheckBox("File & Resource Handles")
        self.check_modules = QtWidgets.QCheckBox("Modules & Libraries")
        self.check_database = QtWidgets.QCheckBox("Database Access")
        self.check_scripts = QtWidgets.QCheckBox("Script References")
        self.check_network = QtWidgets.QCheckBox("Network / API Calls")

        for checkbox in (
            self.check_user_input,
            self.check_process_stats,
            self.check_child_processes,
            self.check_files_resources,
            self.check_modules,
            self.check_database,
            self.check_scripts,
            self.check_network,
        ):
            checkbox.setChecked(True)

        checkboxes = [
            self.check_user_input,
            self.check_process_stats,
            self.check_child_processes,
            self.check_files_resources,
            self.check_modules,
            self.check_database,
            self.check_scripts,
            self.check_network,
        ]

        for idx, checkbox in enumerate(checkboxes):
            row = idx // 2
            col = idx % 2
            grid.addWidget(checkbox, row, col)

        return box

    def _build_controls_section(self) -> QtWidgets.QGroupBox:
        box = QtWidgets.QGroupBox("Controls")
        layout = QtWidgets.QVBoxLayout(box)

        button_row = QtWidgets.QHBoxLayout()
        self.run_button = QtWidgets.QPushButton("Run & Start Logging")
        self.run_button.clicked.connect(self._on_run_clicked)
        self.stop_button = QtWidgets.QPushButton("Stop Logging")
        self.stop_button.clicked.connect(lambda: self.stop_logging(user_triggered=True))
        self.stop_button.setEnabled(False)

        button_row.addWidget(self.run_button)
        button_row.addWidget(self.stop_button)

        layout.addLayout(button_row)

        hotkey_label = QtWidgets.QLabel(
            f"Keyboard macros: Start logging ({HOTKEY_START}), Stop logging ({HOTKEY_STOP})."
        )
        hotkey_label.setWordWrap(True)
        layout.addWidget(hotkey_label)

        return box

    def _build_status_section(self) -> QtWidgets.QGroupBox:
        box = QtWidgets.QGroupBox("Runtime Status")
        vbox = QtWidgets.QVBoxLayout(box)
        self.status_output = QtWidgets.QTextEdit()
        self.status_output.setReadOnly(True)
        vbox.addWidget(self.status_output)
        return box

    @staticmethod
    def _wrap_with_widget(layout: QtWidgets.QLayout) -> QtWidgets.QWidget:
        widget = QtWidgets.QWidget()
        widget.setLayout(layout)
        return widget

    # --- Event handlers --------------------------------------------------

    def _choose_executable(self) -> None:
        path, _ = QtWidgets.QFileDialog.getOpenFileName(self, "Select Executable", str(Path.cwd()), "Executables (*.exe);;All Files (*)")
        if path:
            self.exe_path_edit.setText(path)

    def _choose_log_file(self) -> None:
        path, _ = QtWidgets.QFileDialog.getSaveFileName(self, "Select Log File", self.log_path_edit.text(), "Text Files (*.txt);;All Files (*)")
        if path:
            self.log_path_edit.setText(path)

    def _on_run_clicked(self) -> None:
        if self._logging_active:
            self._append_status("Logging already active.")
            return

        exe_path = Path(self.exe_path_edit.text().strip())
        if not exe_path.exists():
            self._append_status("Executable path is invalid or missing.")
            QtWidgets.QMessageBox.warning(self, "Invalid Path", "Please select a valid executable path before starting logging.")
            return

        log_path_input = Path(self.log_path_edit.text().strip())
        log_path = self._normalise_log_path(log_path_input)
        if not log_path:
            QtWidgets.QMessageBox.warning(self, "Log Path Error", "Please provide a valid log file path.")
            return

        try:
            log_manager.start(log_path)
        except Exception as exc:
            self._append_status(f"Failed to initialise log file: {exc}")
            QtWidgets.QMessageBox.critical(self, "Logging Error", f"Unable to open log file.\n\n{exc}")
            return

        options = self._collect_options()
        self._monitor_manager.configure(options)
        self._monitor_manager.attach_process(None)
        self._monitor_manager.start_monitors()

        self._logging_active = True
        self.stop_button.setEnabled(True)
        self.run_button.setEnabled(False)

        self._append_status(f"Logging started. Output: {log_path}")
        log_manager.log_event("SYSTEM", "Logging started via GUI.", {"log_path": str(log_path)})

        self._launch_process(exe_path)

    def stop_logging(self, user_triggered: bool = False) -> None:
        if not self._logging_active:
            if user_triggered:
                self._append_status("Logging is not active.")
            return

        self._poll_timer.stop()

        if self._process and self._process.poll() is None and user_triggered:
            terminate = QtWidgets.QMessageBox.question(
                self,
                "Stop Logging",
                "Target process is still running. Do you want to terminate it?",
                QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No,
            )
            if terminate == QtWidgets.QMessageBox.Yes:
                self._terminate_process()

        self._monitor_manager.stop_monitors()
        log_manager.log_event("SYSTEM", "Logging stopped.", {"user_triggered": user_triggered})
        log_manager.stop()

        self._logging_active = False
        self._process = None
        self._monitor_manager.attach_process(None)
        self.stop_button.setEnabled(False)
        self.run_button.setEnabled(True)
        self._append_status("Logging stopped.")

    def closeEvent(self, event: QtGui.QCloseEvent) -> None:  # noqa: N802
        self.stop_logging(user_triggered=False)
        self._unregister_hotkeys()
        super().closeEvent(event)

    # --- Logging helpers -------------------------------------------------

    def _collect_options(self) -> LogOptions:
        return LogOptions(
            user_input=self.check_user_input.isChecked(),
            process_stats=self.check_process_stats.isChecked(),
            child_processes=self.check_child_processes.isChecked(),
            files_and_resources=self.check_files_resources.isChecked(),
            modules_and_libraries=self.check_modules.isChecked(),
            database_activity=self.check_database.isChecked(),
            script_activity=self.check_scripts.isChecked(),
            network_activity=self.check_network.isChecked(),
        )

    def _normalise_log_path(self, path: Path) -> Optional[Path]:
        if path.is_dir():
            filename = f"app_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
            return path / filename
        if not path.parent.exists():
            try:
                path.parent.mkdir(parents=True, exist_ok=True)
            except OSError:
                return None
        return path

    def _launch_process(self, exe_path: Path) -> None:
        working_dir = exe_path.parent
        creationflags = 0
        if os.name == "nt":
            creationflags = getattr(subprocess, "CREATE_NEW_CONSOLE", 0)

        try:
            popen = subprocess.Popen(
                [str(exe_path)],
                cwd=str(working_dir),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                creationflags=creationflags,
            )
        except Exception as exc:
            self._append_status(f"Failed to launch executable: {exc}")
            QtWidgets.QMessageBox.critical(self, "Launch Error", f"Unable to start the executable.\n\n{exc}")
            self.stop_logging(user_triggered=False)
            return

        self._process = popen
        self._monitor_manager.attach_process(popen.pid)
        self._poll_timer.start()

        info = {
            "pid": popen.pid,
            "exe": str(exe_path),
            "cwd": str(working_dir),
        }
        log_manager.log_event("PROCESS", "Target executable launched.", info)
        self._append_status(f"Process started (PID: {popen.pid}).")

        threading.Thread(target=self._pipe_reader, args=(popen.stdout, "STDOUT"), daemon=True).start()
        threading.Thread(target=self._pipe_reader, args=(popen.stderr, "STDERR"), daemon=True).start()

    def _pipe_reader(self, pipe, label: str) -> None:
        if pipe is None:
            return
        with pipe:
            for line in iter(pipe.readline, b""):
                decoded = line.decode(errors="replace").strip()
                if not decoded:
                    continue
                log_manager.log_event("PROCESS_OUTPUT", f"{label}: {decoded}")
                self._invoke_on_main_thread(lambda message=f"{label}: {decoded}": self._append_status(message))

    def _poll_process_state(self) -> None:
        if not self._process or not self._logging_active:
            self._poll_timer.stop()
            return
        return_code = self._process.poll()
        if return_code is not None:
            log_manager.log_event("PROCESS", "Process exited.", {"return_code": return_code, "pid": self._process.pid})
            self._append_status(f"Process exited with code {return_code}.")
            self.stop_logging(user_triggered=False)

    def _terminate_process(self) -> None:
        if not self._process:
            return

        proc = self._process

        try:
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
        except Exception:
            pass

    def _append_status(self, text: str) -> None:
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.status_output.append(f"[{timestamp}] {text}")

    # --- Keyboard hotkey handling ---------------------------------------

    def _register_hotkeys(self) -> None:
        if keyboard_lib is None:
            self._append_status("Global keyboard hotkeys are unavailable (keyboard module not installed or unsupported).")
            return

        try:
            self._hotkey_start_id = keyboard_lib.add_hotkey(
                HOTKEY_START, lambda: self._invoke_on_main_thread(self._on_run_clicked)
            )
            self._hotkey_stop_id = keyboard_lib.add_hotkey(
                HOTKEY_STOP, lambda: self._invoke_on_main_thread(lambda: self.stop_logging(user_triggered=True)))
            self._hotkeys_registered = True
            self._append_status(f"Global hotkeys registered: start [{HOTKEY_START}], stop [{HOTKEY_STOP}].")
        except Exception as exc:  # pragma: no cover - depends on OS permissions
            self._append_status(f"Failed to register global hotkeys: {exc}")

    def _unregister_hotkeys(self) -> None:
        if keyboard_lib is None or not self._hotkeys_registered:
            return
        try:
            if self._hotkey_start_id is not None:
                keyboard_lib.remove_hotkey(self._hotkey_start_id)
            if self._hotkey_stop_id is not None:
                keyboard_lib.remove_hotkey(self._hotkey_stop_id)
        except Exception:
            pass
        self._hotkeys_registered = False
        self._hotkey_start_id = None
        self._hotkey_stop_id = None

    def _invoke_on_main_thread(self, callable_obj) -> None:
        QtCore.QTimer.singleShot(0, callable_obj)


def main() -> int:
    app = QtWidgets.QApplication(sys.argv)
    window = MainWindow()
    window.show()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())

