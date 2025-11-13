from __future__ import annotations

import queue
import threading
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable, Dict, Optional

from monitors import (
    APICallMonitor,
    DatabaseActivityMonitor,
    FileActivityMonitor,
    InputMonitor,
    ModuleLoadMonitor,
    NetworkActivityMonitor,
    ProcessTreeMonitor,
    ResourceUsageMonitor,
)


@dataclass
class MonitorConfig:
    user_input: bool = True
    processes: bool = True
    file_activity: bool = True
    modules: bool = True
    network: bool = True
    resources: bool = True
    databases: bool = True
    api_calls: bool = False


class LoggingController:
    """Coordinate monitors, log writing, and state transitions."""

    def __init__(self, ui_callback: Callable[[str], None]) -> None:
        self._ui_callback = ui_callback
        self._queue: queue.Queue[str] = queue.Queue()
        self._log_path: Optional[Path] = None
        self._log_file_lock = threading.Lock()
        self._log_file_handle = None

        self._writer_thread: Optional[threading.Thread] = None
        self._writer_stop_event = threading.Event()

        self._target_pid: Optional[int] = None
        self._config = MonitorConfig()
        self._monitors: Dict[str, object] = {}
        self._logging_active = False

    def set_log_path(self, path: str) -> None:
        self._log_path = Path(path)
        if not self._log_path.parent.exists():
            self._log_path.parent.mkdir(parents=True, exist_ok=True)

    def prepare_monitors(self, pid: int, config: MonitorConfig) -> None:
        self._target_pid = pid
        self._config = config
        self._shutdown_monitors()
        self._monitors = self._build_monitors(config)
        for monitor in self._monitors.values():
            if hasattr(monitor, "configure"):
                monitor.configure(pid)
            if hasattr(monitor, "start"):
                monitor.start()
            if hasattr(monitor, "set_logging_active"):
                monitor.set_logging_active(False)

        self._emit_status("Monitors initialised.")

    def start_logging(self) -> None:
        if self._logging_active:
            return
        if not self._log_path:
            raise RuntimeError("Log path must be set before starting logging.")

        self._open_log_file()
        self._start_writer()

        self._logging_active = True
        self._emit("[Logging] START")
        for monitor in self._monitors.values():
            if hasattr(monitor, "set_logging_active"):
                monitor.set_logging_active(True)

    def stop_logging(self) -> None:
        if not self._logging_active:
            return
        self._logging_active = False
        for monitor in self._monitors.values():
            if hasattr(monitor, "set_logging_active"):
                monitor.set_logging_active(False)
        self._emit("[Logging] STOP")
        self._stop_writer()

    def shutdown(self) -> None:
        self.stop_logging()
        self._shutdown_monitors()
        self._close_log_file()

    def emit(self, message: str) -> None:
        self._queue.put(f"{self._timestamp()} {message}")

    def _emit(self, message: str) -> None:
        self.emit(message)

    def _emit_status(self, message: str) -> None:
        timestamped = f"{self._timestamp()} {message}"
        self._ui_callback(timestamped)

    def _build_monitors(self, config: MonitorConfig) -> Dict[str, object]:
        monitors: Dict[str, object] = {}
        if config.user_input:
            monitors["user_input"] = InputMonitor(self.emit)
        if config.processes:
            monitors["processes"] = ProcessTreeMonitor(self.emit)
        if config.file_activity:
            monitors["file_activity"] = FileActivityMonitor(self.emit)
        if config.modules:
            monitors["modules"] = ModuleLoadMonitor(self.emit)
        if config.network:
            monitors["network"] = NetworkActivityMonitor(self.emit)
        if config.resources:
            monitors["resources"] = ResourceUsageMonitor(self.emit)
        if config.databases:
            monitors["databases"] = DatabaseActivityMonitor(self.emit)
        if config.api_calls:
            monitors["api_calls"] = APICallMonitor(self.emit)
        return monitors

    def _shutdown_monitors(self) -> None:
        for monitor in self._monitors.values():
            if hasattr(monitor, "set_logging_active"):
                monitor.set_logging_active(False)
            if hasattr(monitor, "stop"):
                try:
                    monitor.stop()
                except Exception:  # pragma: no cover - defensive
                    pass
            if hasattr(monitor, "join"):
                try:
                    monitor.join(timeout=2.0)
                except Exception:  # pragma: no cover
                    pass
        self._monitors.clear()

    def _start_writer(self) -> None:
        if self._writer_thread and self._writer_thread.is_alive():
            return
        self._writer_stop_event.clear()
        self._writer_thread = threading.Thread(
            target=self._writer_loop, name="LogWriter", daemon=True
        )
        self._writer_thread.start()

    def _stop_writer(self) -> None:
        if not self._writer_thread:
            return
        self._writer_stop_event.set()
        self._writer_thread.join(timeout=2.0)
        self._writer_thread = None
        self._writer_stop_event.clear()

    def _writer_loop(self) -> None:
        while not self._writer_stop_event.is_set() or not self._queue.empty():
            try:
                message = self._queue.get(timeout=0.5)
            except queue.Empty:
                continue
            self._ui_callback(message)
            if self._log_file_handle:
                with self._log_file_lock:
                    self._log_file_handle.write(message + "\n")
                    self._log_file_handle.flush()

    def _open_log_file(self) -> None:
        if self._log_file_handle or not self._log_path:
            return
        self._log_path.parent.mkdir(parents=True, exist_ok=True)
        self._log_file_handle = self._log_path.open("a", encoding="utf-8")
        self._log_file_handle.write(f"# Log session started {self._timestamp()}\n")

    def _close_log_file(self) -> None:
        if self._log_file_handle:
            with self._log_file_lock:
                self._log_file_handle.write(f"# Log session closed {self._timestamp()}\n")
                self._log_file_handle.close()
            self._log_file_handle = None

    @staticmethod
    def _timestamp() -> str:
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
