"""GUI entry point for the executable activity logger."""
from __future__ import annotations

import os
import shlex
import sys
from datetime import datetime
from pathlib import Path
from typing import Callable, Dict, List, Optional

from PySide6 import QtCore, QtGui, QtWidgets

from .log_manager import LogManager, LogManagerError


DEFAULT_MACRO_START = "ctrl+alt+shift+f5"
DEFAULT_MACRO_STOP = "ctrl+alt+shift+f6"


class StatusBridge(QtCore.QObject):
    status_signal = QtCore.Signal(str)


class MacroBridge(QtCore.QObject):
    start_signal = QtCore.Signal()
    stop_signal = QtCore.Signal()

    def emit_start(self) -> None:
        self.start_signal.emit()

    def emit_stop(self) -> None:
        self.stop_signal.emit()


class KeyboardMacroManager:
    def __init__(
        self,
        bridge: MacroBridge,
        start_combo: str = DEFAULT_MACRO_START,
        stop_combo: str = DEFAULT_MACRO_STOP,
        status_callback: Optional[Callable[[str], None]] = None,
    ) -> None:
        self._keyboard = None
        self._hooks: List[str] = []
        self._status_callback = status_callback
        try:
            import keyboard  # type: ignore
        except ImportError as exc:  # pragma: no cover - optional dependency
            self._status(f"Keyboard macros disabled (missing dependency 'keyboard'): {exc}")
            return
        except Exception as exc:  # pragma: no cover
            self._status(f"Keyboard macros unavailable: {exc}")
            return

        self._keyboard = keyboard
        try:
            self._hooks.append(keyboard.add_hotkey(start_combo, bridge.emit_start))
            self._hooks.append(keyboard.add_hotkey(stop_combo, bridge.emit_stop))
            self._status(
                f"Keyboard macros active: start ({start_combo}), stop ({stop_combo})."
            )
        except Exception as exc:  # pragma: no cover
            self._status(f"Failed to register keyboard macros: {exc}")
            self._keyboard = None
            self._hooks.clear()

    def cleanup(self) -> None:
        if not self._keyboard:
            return
        try:
            for hook in self._hooks:
                self._keyboard.remove_hotkey(hook)
        except Exception:
            pass
        self._hooks.clear()
        self._keyboard = None

    def _status(self, message: str) -> None:
        if self._status_callback:
            try:
                self._status_callback(message)
            except Exception:
                pass


DATA_TOGGLE_DEFINITIONS = {
    "user_input": ("User input (keyboard & mouse)", True),
    "process_tree": ("Processes & child workflows", True),
    "resource_usage": ("Resource usage (CPU, memory, IO)", True),
    "file_activity": ("File activity", True),
    "module_activity": ("Libraries/modules", True),
    "network_activity": ("Network/API/DB activity", True),
}


class MainWindow(QtWidgets.QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Executable Activity Logger")
        self.resize(900, 600)

        self._status_bridge = StatusBridge()
        self._status_bridge.status_signal.connect(self._append_status)

        self._macro_bridge = MacroBridge()
        self._macro_bridge.start_signal.connect(self._start_logging_from_macro)
        self._macro_bridge.stop_signal.connect(self._stop_logging_from_macro)

        self._log_manager = LogManager(status_callback=self._status_bridge.status_signal.emit)

        self._build_ui()

        self._macro_manager = KeyboardMacroManager(
            self._macro_bridge,
            status_callback=self._status_bridge.status_signal.emit,
        )

    # UI construction -------------------------------------------------
    def _build_ui(self) -> None:
        central = QtWidgets.QWidget(self)
        layout = QtWidgets.QVBoxLayout(central)
        layout.setContentsMargins(12, 12, 12, 12)
        layout.setSpacing(10)

        layout.addWidget(self._build_executable_group())
        layout.addWidget(self._build_logging_group())
        layout.addWidget(self._build_macro_help())
        layout.addLayout(self._build_action_buttons())

        self._status_view = QtWidgets.QPlainTextEdit()
        self._status_view.setReadOnly(True)
        self._status_view.setPlaceholderText("Session status will appear here.")
        layout.addWidget(self._status_view, stretch=1)

        self.setCentralWidget(central)

    def _build_executable_group(self) -> QtWidgets.QGroupBox:
        group = QtWidgets.QGroupBox("Target executable")
        grid = QtWidgets.QGridLayout(group)

        self._exe_path_edit = QtWidgets.QLineEdit()
        browse_exe_btn = QtWidgets.QPushButton("Browse…")
        browse_exe_btn.clicked.connect(self._browse_executable)

        self._args_edit = QtWidgets.QLineEdit()
        self._args_edit.setPlaceholderText("Optional arguments for the executable")

        self._log_path_edit = QtWidgets.QLineEdit()
        browse_log_btn = QtWidgets.QPushButton("Browse…")
        browse_log_btn.clicked.connect(self._browse_log_file)

        grid.addWidget(QtWidgets.QLabel("Executable path"), 0, 0)
        grid.addWidget(self._exe_path_edit, 0, 1)
        grid.addWidget(browse_exe_btn, 0, 2)

        grid.addWidget(QtWidgets.QLabel("Program arguments"), 1, 0)
        grid.addWidget(self._args_edit, 1, 1, 1, 2)

        grid.addWidget(QtWidgets.QLabel("Log file path"), 2, 0)
        grid.addWidget(self._log_path_edit, 2, 1)
        grid.addWidget(browse_log_btn, 2, 2)

        return group

    def _build_logging_group(self) -> QtWidgets.QGroupBox:
        group = QtWidgets.QGroupBox("Data capture options")
        grid = QtWidgets.QGridLayout(group)

        self._toggle_boxes: Dict[str, QtWidgets.QCheckBox] = {}
        row = 0
        for key, (label, default) in DATA_TOGGLE_DEFINITIONS.items():
            checkbox = QtWidgets.QCheckBox(label)
            checkbox.setChecked(default)
            self._toggle_boxes[key] = checkbox
            grid.addWidget(checkbox, row // 2, row % 2)
            row += 1

        self._terminate_checkbox = QtWidgets.QCheckBox("Terminate target when stopping logging")
        self._terminate_checkbox.setChecked(False)
        grid.addWidget(self._terminate_checkbox, (row + 1) // 2, 0, 1, 2)

        return group

    def _build_macro_help(self) -> QtWidgets.QGroupBox:
        group = QtWidgets.QGroupBox("Keyboard macros")
        layout = QtWidgets.QVBoxLayout(group)
        layout.addWidget(
            QtWidgets.QLabel(
                f"Start logging: {DEFAULT_MACRO_START}\nStop logging: {DEFAULT_MACRO_STOP}\n"
                "Macros require the optional 'keyboard' package and administrative privileges on Windows."
            )
        )
        return group

    def _build_action_buttons(self) -> QtWidgets.QHBoxLayout:
        layout = QtWidgets.QHBoxLayout()
        layout.addStretch(1)

        self._start_btn = QtWidgets.QPushButton("Run & Log")
        self._start_btn.clicked.connect(self._start_logging)
        layout.addWidget(self._start_btn)

        self._stop_btn = QtWidgets.QPushButton("Stop Logging")
        self._stop_btn.clicked.connect(self._stop_logging)
        self._stop_btn.setEnabled(False)
        layout.addWidget(self._stop_btn)

        return layout

    # Event handlers --------------------------------------------------
    def _browse_executable(self) -> None:
        path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self,
            "Select executable",
            self._default_start_dir(),
            "Executables (*.exe *.bat *.cmd *.ps1);;All files (*)",
        )
        if path:
            self._exe_path_edit.setText(path)

    def _browse_log_file(self) -> None:
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self,
            "Select log file",
            str(Path(self._default_start_dir()) / "logs" / "session.log"),
            "Log files (*.log);;All files (*)",
        )
        if path:
            self._log_path_edit.setText(path)

    def _start_logging(self) -> None:
        if self._log_manager.is_active():
            self._append_status("Logging session already running.")
            return

        exe_path = self._exe_path_edit.text().strip()
        if not exe_path:
            self._show_error("Please select an executable to launch.")
            return

        try:
            command = self._build_command(exe_path, self._args_edit.text())
        except ValueError as exc:
            self._show_error(str(exc))
            return

        log_path_text = self._log_path_edit.text().strip()
        try:
            log_path = self._resolve_log_path(exe_path, log_path_text)
        except ValueError as exc:
            self._show_error(str(exc))
            return

        toggles = {key: box.isChecked() for key, box in self._toggle_boxes.items()}
        if not any(toggles.values()):
            self._show_error("Select at least one data type to capture.")
            return

        try:
            pid = self._log_manager.start_logging(
                command=command,
                log_path=log_path,
                toggles=toggles,
                working_directory=Path(exe_path).parent,
            )
        except LogManagerError as exc:
            self._show_error(str(exc))
            return
        except Exception as exc:
            self._show_error(f"Unexpected error: {exc}")
            return

        self._append_status(f"Logging started for PID {pid}. Output -> {log_path}")
        self._update_controls(logging_active=True)

    def _stop_logging(self) -> None:
        if not self._log_manager.is_active():
            self._append_status("No active logging session to stop.")
            return

        terminate = self._terminate_checkbox.isChecked()
        self._log_manager.stop_logging(terminate_process=terminate)
        self._update_controls(logging_active=False)

    def _start_logging_from_macro(self) -> None:
        QtCore.QTimer.singleShot(0, self._start_logging)

    def _stop_logging_from_macro(self) -> None:
        QtCore.QTimer.singleShot(0, self._stop_logging)

    def _append_status(self, message: str) -> None:
        timestamp = datetime.now().strftime("%H:%M:%S")
        self._status_view.appendPlainText(f"[{timestamp}] {message}")
        cursor = self._status_view.textCursor()
        cursor.movePosition(QtGui.QTextCursor.End)
        self._status_view.setTextCursor(cursor)
        self._status_view.ensureCursorVisible()
        if message.lower().startswith("logging session stopped"):
            self._update_controls(logging_active=False)

    def _update_controls(self, logging_active: bool) -> None:
        self._start_btn.setEnabled(not logging_active)
        self._stop_btn.setEnabled(logging_active)
        for box in self._toggle_boxes.values():
            box.setEnabled(not logging_active)
        self._exe_path_edit.setEnabled(not logging_active)
        self._args_edit.setEnabled(not logging_active)
        self._log_path_edit.setEnabled(not logging_active)

    def _build_command(self, exe_path: str, args: str) -> List[str]:
        exe_path = exe_path.strip().strip('"')
        path_obj = Path(exe_path)
        if not path_obj.exists():
            raise ValueError(f"Executable does not exist: {exe_path}")
        if not path_obj.is_file():
            raise ValueError("Selected executable path is not a file")

        if args.strip():
            split_args = self._split_arguments(args)
        else:
            split_args = []

        return [str(path_obj)] + split_args

    def _split_arguments(self, arg_string: str) -> List[str]:
        if os.name == "nt":
            return shlex.split(arg_string, posix=False)
        return shlex.split(arg_string)

    def _resolve_log_path(self, exe_path: str, log_input: str) -> Path:
        exe_stem = Path(exe_path).stem or "session"
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        if not log_input:
            default_dir = Path.home() / "exe_activity_logs"
            return (default_dir / f"{exe_stem}_{timestamp}.log").resolve()

        candidate = Path(log_input).expanduser()
        if candidate.exists() and candidate.is_dir():
            return (candidate / f"{exe_stem}_{timestamp}.log").resolve()

        if candidate.suffix:
            return candidate.resolve()

        # Treat as directory path even if it does not yet exist
        return (candidate / f"{exe_stem}_{timestamp}.log").resolve()

    def _default_start_dir(self) -> str:
        exe_text = self._exe_path_edit.text().strip()
        if exe_text:
            return str(Path(exe_text).expanduser().parent)
        return str(Path.home())

    def _show_error(self, message: str) -> None:
        QtWidgets.QMessageBox.critical(self, "Logging Error", message)
        self._append_status(message)

    def closeEvent(self, event: QtGui.QCloseEvent) -> None:
        if self._log_manager.is_active():
            self._log_manager.stop_logging(terminate_process=False)
        if self._macro_manager:
            self._macro_manager.cleanup()
        super().closeEvent(event)


def run() -> None:
    app = QtWidgets.QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    run()

