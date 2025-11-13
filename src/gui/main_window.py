from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional

from PySide6.QtCore import Qt, QTimer, Signal, Slot
from PySide6.QtGui import QAction
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
    QFormLayout,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QSizePolicy,
    QStatusBar,
    QTextEdit,
    QToolBar,
    QVBoxLayout,
    QWidget,
    QFileDialog,
)

from services import GlobalHotkeys, LoggingController, MonitorConfig


class MainWindow(QMainWindow):
    log_message = Signal(str)

    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Executable Instrumentation Logger")
        self.resize(980, 720)

        self._controller = LoggingController(self.log_message.emit)
        self._hotkeys = GlobalHotkeys(
            on_start=self._handle_hotkey_start,
            on_stop=self._handle_hotkey_stop,
            status_callback=self.log_message.emit,
        )
        self._process: Optional[subprocess.Popen] = None
        self._process_timer = QTimer(self)
        self._process_timer.setInterval(1000)
        self._process_timer.timeout.connect(self._poll_process)

        self.log_message.connect(self._append_log)

        central = QWidget(self)
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)
        layout.setContentsMargins(12, 12, 12, 12)
        layout.setSpacing(10)

        layout.addWidget(self._build_paths_group())
        layout.addWidget(self._build_toggle_group())
        layout.addLayout(self._build_action_buttons())

        self.log_output = QTextEdit(self)
        self.log_output.setReadOnly(True)
        self.log_output.setPlaceholderText("Log output will appear here once logging starts...")
        layout.addWidget(self.log_output, stretch=1)

        self._setup_toolbar()
        self.setStatusBar(QStatusBar(self))

    def _setup_toolbar(self) -> None:
        toolbar = QToolBar("Controls", self)
        toolbar.setMovable(False)

        start_action = QAction("Start Logging (Ctrl+Shift+Alt+S)", self)
        start_action.triggered.connect(self._handle_hotkey_start)
        toolbar.addAction(start_action)

        stop_action = QAction("Stop Logging (Ctrl+Shift+Alt+E)", self)
        stop_action.triggered.connect(self._handle_hotkey_stop)
        toolbar.addAction(stop_action)

        self.addToolBar(Qt.TopToolBarArea, toolbar)

    def _build_paths_group(self) -> QWidget:
        group = QGroupBox("Executable and Output")
        form = QFormLayout()
        form.setLabelAlignment(Qt.AlignRight)
        form.setFormAlignment(Qt.AlignTop)

        self.exe_path_edit = QLineEdit(self)
        self.exe_path_edit.setPlaceholderText("Select the .exe to launch")
        exe_browse = QPushButton("Browse...", self)
        exe_browse.clicked.connect(self._select_executable)

        exe_row = QHBoxLayout()
        exe_row.addWidget(self.exe_path_edit)
        exe_row.addWidget(exe_browse)
        form.addRow(QLabel("Executable:"), exe_row)

        self.log_path_edit = QLineEdit(self)
        self.log_path_edit.setPlaceholderText("Select where logs should be written")
        log_browse = QPushButton("Browse...", self)
        log_browse.clicked.connect(self._select_log_destination)

        log_row = QHBoxLayout()
        log_row.addWidget(self.log_path_edit)
        log_row.addWidget(log_browse)
        form.addRow(QLabel("Log File:"), log_row)

        group.setLayout(form)
        return group

    def _build_toggle_group(self) -> QWidget:
        group = QGroupBox("Data to Capture")
        grid = QGridLayout()
        grid.setSpacing(4)

        self.toggle_map: Dict[str, QCheckBox] = {
            "user_input": QCheckBox("User input (keyboard & mouse)"),
            "processes": QCheckBox("Process tree & background workers"),
            "file_activity": QCheckBox("Script/file access"),
            "modules": QCheckBox("Loaded libraries / modules"),
            "network": QCheckBox("Network & API endpoints"),
            "resources": QCheckBox("CPU / memory / IO resources"),
            "databases": QCheckBox("Database connections"),
            "api_calls": QCheckBox("Win32 API tracing (ETW, Windows only)"),
        }

        defaults = {
            "user_input": True,
            "processes": True,
            "file_activity": True,
            "modules": True,
            "network": True,
            "resources": True,
            "databases": True,
            "api_calls": False,
        }

        for key, checkbox in self.toggle_map.items():
            checkbox.setChecked(defaults.get(key, False))

        row = 0
        col = 0
        for checkbox in self.toggle_map.values():
            checkbox.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
            grid.addWidget(checkbox, row, col)
            col += 1
            if col > 1:
                col = 0
                row += 1

        group.setLayout(grid)
        return group

    def _build_action_buttons(self) -> QHBoxLayout:
        layout = QHBoxLayout()

        self.run_button = QPushButton("Run & Attach", self)
        self.run_button.clicked.connect(self._run_and_attach)
        self.run_button.setDefault(True)

        self.start_button = QPushButton("Start Logging", self)
        self.start_button.clicked.connect(self._handle_hotkey_start)
        self.start_button.setEnabled(False)

        self.stop_button = QPushButton("Stop Logging", self)
        self.stop_button.clicked.connect(self._handle_hotkey_stop)
        self.stop_button.setEnabled(False)

        self.terminate_button = QPushButton("Terminate Process", self)
        self.terminate_button.clicked.connect(self._terminate_process)
        self.terminate_button.setEnabled(False)

        layout.addWidget(self.run_button)
        layout.addStretch(1)
        layout.addWidget(self.start_button)
        layout.addWidget(self.stop_button)
        layout.addWidget(self.terminate_button)

        return layout

    def _select_executable(self) -> None:
        path, _ = QFileDialog.getOpenFileName(
            self, "Select Executable", str(Path.home()), "Executables (*.exe);;All Files (*)"
        )
        if path:
            self.exe_path_edit.setText(path)

    def _select_log_destination(self) -> None:
        path, _ = QFileDialog.getSaveFileName(
            self,
            "Select Log Destination",
            str(Path.home() / f"log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"),
            "Text files (*.txt *.log);;All files (*)",
        )
        if path:
            self.log_path_edit.setText(path)

    def _current_config(self) -> MonitorConfig:
        return MonitorConfig(
            user_input=self.toggle_map["user_input"].isChecked(),
            processes=self.toggle_map["processes"].isChecked(),
            file_activity=self.toggle_map["file_activity"].isChecked(),
            modules=self.toggle_map["modules"].isChecked(),
            network=self.toggle_map["network"].isChecked(),
            resources=self.toggle_map["resources"].isChecked(),
            databases=self.toggle_map["databases"].isChecked(),
            api_calls=self.toggle_map["api_calls"].isChecked(),
        )

    def _default_log_path(self) -> Path:
        base_dir = Path.home() / "InstrumentationLogs"
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        base_dir.mkdir(parents=True, exist_ok=True)
        return base_dir / f"session_{timestamp}.log"

    def _run_and_attach(self) -> None:
        if self._process and self._process.poll() is None:
            QMessageBox.warning(
                self,
                "Process already running",
                "A target process is already running. Terminate it before launching another.",
            )
            return

        exe_path = self.exe_path_edit.text().strip()
        if not exe_path:
            QMessageBox.warning(self, "Missing executable", "Please select an executable to launch.")
            return
        if not os.path.exists(exe_path):
            QMessageBox.critical(self, "Invalid executable", f"The path '{exe_path}' does not exist.")
            return

        log_path_text = self.log_path_edit.text().strip()
        log_path = Path(log_path_text) if log_path_text else self._default_log_path()
        self.log_path_edit.setText(str(log_path))

        try:
            self._controller.set_log_path(str(log_path))
        except Exception as exc:
            QMessageBox.critical(self, "Log path error", f"Unable to set log path: {exc}")
            return

        try:
            creationflags = 0
            if sys.platform.startswith("win"):
                creationflags = subprocess.CREATE_NEW_PROCESS_GROUP  # type: ignore[attr-defined]
            self._process = subprocess.Popen(
                exe_path,
                cwd=str(Path(exe_path).parent),
                creationflags=creationflags,
            )
        except Exception as exc:
            QMessageBox.critical(self, "Launch failed", f"Could not start process: {exc}")
            self._process = None
            return

        config = self._current_config()
        self._controller.prepare_monitors(self._process.pid, config)
        self._process_timer.start()

        self.run_button.setEnabled(False)
        self.start_button.setEnabled(True)
        self.stop_button.setEnabled(True)
        self.terminate_button.setEnabled(True)

        self.statusBar().showMessage(f"Process running (pid {self._process.pid}).")
        self.log_message.emit(
            f"Attached to process PID={self._process.pid}. Use the hotkey or button to start logging."
        )

        self._hotkeys.register()

    def _terminate_process(self) -> None:
        if not self._process:
            return
        if self._process.poll() is None:
            try:
                self._process.terminate()
                self._process.wait(timeout=5)
            except Exception:
                self._process.kill()
        self._process = None
        self._after_process_exit()

    def _poll_process(self) -> None:
        if self._process and self._process.poll() is not None:
            exit_code = self._process.returncode
            self.log_message.emit(f"Process exited with code {exit_code}.")
            self._process = None
            self._after_process_exit()

    def _after_process_exit(self) -> None:
        self._process_timer.stop()
        self._controller.stop_logging()
        self._controller.shutdown()
        self._hotkeys.unregister()

        self.run_button.setEnabled(True)
        self.start_button.setEnabled(False)
        self.stop_button.setEnabled(False)
        self.terminate_button.setEnabled(False)
        self.statusBar().showMessage("Process stopped.")

    def _handle_hotkey_start(self) -> None:
        try:
            self._controller.start_logging()
            self.statusBar().showMessage("Logging active.")
        except RuntimeError as exc:
            QMessageBox.critical(self, "Unable to start logging", str(exc))

    def _handle_hotkey_stop(self) -> None:
        self._controller.stop_logging()
        self.statusBar().showMessage("Logging paused.")

    @Slot(str)
    def _append_log(self, message: str) -> None:
        self.log_output.append(message)
        self.log_output.verticalScrollBar().setValue(self.log_output.verticalScrollBar().maximum())

    def closeEvent(self, event) -> None:
        self._terminate_process()
        self._controller.shutdown()
        self._hotkeys.unregister()
        super().closeEvent(event)


def run_application() -> int:
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    return app.exec()


if __name__ == "__main__":
    sys.exit(run_application())
