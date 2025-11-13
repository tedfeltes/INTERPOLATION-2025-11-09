"""Coordinates watcher lifecycles and writes structured log output."""
from __future__ import annotations

import datetime as dt
import os
import queue
import subprocess
import threading
from pathlib import Path
from typing import Callable, Dict, Iterable, Optional, Sequence

from .watchers.base import BaseWatcher
from .watchers.file_watcher import FileWatcher
from .watchers.module_watcher import ModuleWatcher
from .watchers.network_watcher import NetworkWatcher
from .watchers.process_watcher import ProcessWatcher
from .watchers.user_input import UserInputWatcher


class LogManagerError(Exception):
    """Raised when the logging engine encounters an unrecoverable issue."""


class LogManager:
    """High-level controller responsible for the capture workflow."""

    def __init__(self, status_callback: Optional[Callable[[str], None]] = None) -> None:
        self._queue: "queue.Queue[dict]" = queue.Queue()
        self._log_file: Optional[object] = None
        self._log_thread: Optional[threading.Thread] = None
        self._monitor_thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()
        self._status_callback = status_callback
        self._watchers: Dict[str, BaseWatcher] = {}
        self._process: Optional[subprocess.Popen] = None
        self._current_log_path: Optional[Path] = None
        self._lock = threading.Lock()
        self._active = False

    def is_active(self) -> bool:
        return self._active

    def start_logging(
        self,
        command: Sequence[str],
        log_path: Path,
        toggles: Dict[str, bool],
        working_directory: Optional[Path] = None,
        environment: Optional[Dict[str, str]] = None,
    ) -> int:
        with self._lock:
            if self._active:
                raise LogManagerError("Logging session already active")
            self._active = True

            try:
                log_path = log_path.expanduser().resolve()
                log_path.parent.mkdir(parents=True, exist_ok=True)
            except Exception as exc:
                self._active = False
                raise LogManagerError(f"Unable to prepare log file: {exc}") from exc

            self._current_log_path = log_path

            try:
                self._log_file = log_path.open("a", encoding="utf-8")
            except OSError as exc:
                self._active = False
                raise LogManagerError(f"Unable to open log file '{log_path}': {exc}") from exc

            self._stop_event.clear()
            self._queue = queue.Queue()

            self._write_session_header(command, log_path)

            creationflags = 0
            startupinfo = None
            if os.name == "nt":
                creationflags = subprocess.CREATE_NEW_PROCESS_GROUP  # type: ignore[attr-defined]
                startupinfo = subprocess.STARTUPINFO()
                startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW  # type: ignore[attr-defined]

            env = os.environ.copy()
            if environment:
                env.update(environment)

            try:
                self._process = subprocess.Popen(
                    list(command),
                    cwd=str(working_directory) if working_directory else None,
                    creationflags=creationflags,
                    startupinfo=startupinfo,
                    env=env,
                )
            except FileNotFoundError as exc:
                self._cleanup_file_resources()
                self._active = False
                raise LogManagerError(f"Executable not found: {command[0]}") from exc
            except PermissionError as exc:
                self._cleanup_file_resources()
                self._active = False
                raise LogManagerError(f"Permission denied when launching '{command[0]}'") from exc
            except Exception as exc:
                self._cleanup_file_resources()
                self._active = False
                raise LogManagerError(f"Failed to launch process: {exc}") from exc

            pid = self._process.pid
            self._status(f"Started logging session for PID {pid}")
            self._enqueue_event(
                "session",
                "start",
                f"Launched target process (PID {pid})",
                {"command": list(command), "pid": pid},
            )

            self._log_thread = threading.Thread(target=self._log_worker, daemon=True, name="log-writer")
            self._log_thread.start()

            self._instantiate_watchers(pid, toggles)
            for watcher in self._watchers.values():
                watcher.start()

            self._monitor_thread = threading.Thread(
                target=self._monitor_process_exit,
                daemon=True,
                name="process-monitor",
            )
            self._monitor_thread.start()

            return pid

    def stop_logging(self, terminate_process: bool = False, *, _from_monitor: bool = False) -> None:
        with self._lock:
            if not self._active:
                return
            self._active = False

            self._stop_event.set()

            for watcher in list(self._watchers.values()):
                try:
                    watcher.stop()
                except Exception:
                    pass
            self._watchers.clear()

            if self._process and self._process.poll() is None:
                if terminate_process:
                    self._terminate_process(self._process)
                else:
                    self._enqueue_event(
                        "session",
                        "info",
                        "Target process still running when logging stopped",
                        {"pid": self._process.pid},
                    )
            self._process = None

            if self._monitor_thread and self._monitor_thread.is_alive() and not _from_monitor:
                if threading.current_thread() != self._monitor_thread:
                    self._monitor_thread.join(timeout=1.5)
            self._monitor_thread = None

            if self._log_thread and self._log_thread.is_alive():
                self._log_thread.join(timeout=1.5)
            self._log_thread = None

            self._cleanup_file_resources()
            self._status("Logging session stopped")

    def _write_session_header(self, command: Sequence[str], log_path: Path) -> None:
        if not self._log_file:
            return
        timestamp = dt.datetime.now().isoformat(sep=" ", timespec="seconds")
        header = (
            f"===== Logging session started {timestamp} =====\n"
            f"Command: {' '.join(command)}\n"
            f"Log file: {log_path}\n"
        )
        self._log_file.write(header)
        self._log_file.flush()

    def _log_worker(self) -> None:
        while not self._stop_event.is_set() or not self._queue.empty():
            try:
                entry = self._queue.get(timeout=0.3)
            except queue.Empty:
                continue
            if not self._log_file:
                continue
            line = self._format_entry(entry)
            try:
                self._log_file.write(line + "\n")
                self._log_file.flush()
            except Exception:
                pass

    def _format_entry(self, entry: Dict[str, object]) -> str:
        timestamp = entry.get("timestamp")
        watcher = entry.get("watcher")
        subtype = entry.get("subtype")
        message = entry.get("message")
        metadata = entry.get("metadata") or {}
        pieces = [f"[{timestamp}]", f"{watcher}/{subtype}", str(message)]
        if metadata:
            formatted_meta = ", ".join(f"{k}={metadata[k]!r}" for k in sorted(metadata))
            pieces.append(f"{{{formatted_meta}}}")
        return " | ".join(pieces)

    def _instantiate_watchers(self, pid: int, toggles: Dict[str, bool]) -> None:
        self._watchers = {}

        if toggles.get("user_input", False):
            self._watchers["user_input"] = UserInputWatcher(self._enqueue_event)

        if toggles.get("process_tree", False) or toggles.get("resource_usage", False):
            self._watchers["process"] = ProcessWatcher(
                pid,
                self._enqueue_event,
                track_children=toggles.get("process_tree", False),
                track_resources=toggles.get("resource_usage", False),
                poll_interval=1.0,
            )

        if toggles.get("network_activity", False):
            self._watchers["network"] = NetworkWatcher(pid, self._enqueue_event)

        if toggles.get("file_activity", False):
            self._watchers["file_activity"] = FileWatcher(pid, self._enqueue_event)

        if toggles.get("module_activity", False):
            self._watchers["modules"] = ModuleWatcher(pid, self._enqueue_event)

    def _enqueue_event(self, watcher: str, subtype: str, message: str, metadata: Optional[Dict[str, object]] = None) -> None:
        entry = {
            "timestamp": dt.datetime.now().isoformat(timespec="milliseconds"),
            "watcher": watcher,
            "subtype": subtype,
            "message": message,
            "metadata": metadata or {},
        }
        self._queue.put(entry)

    def _monitor_process_exit(self) -> None:
        process = self._process
        if not process:
            return
        try:
            exit_code = process.wait()
        except Exception as exc:
            self._enqueue_event(
                "process",
                "monitor_error",
                "Process monitoring failed",
                {"exception": repr(exc)},
            )
            return

        self._enqueue_event(
            "process",
            "exited",
            f"Target process exited with code {exit_code}",
            {"pid": process.pid, "exit_code": exit_code},
        )
        self._status(f"Target process exited with code {exit_code}")
        self.stop_logging(terminate_process=False, _from_monitor=True)

    def _terminate_process(self, process: subprocess.Popen) -> None:
        try:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
        except Exception as exc:
            self._enqueue_event(
                "process",
                "terminate_error",
                "Failed to terminate process",
                {"pid": process.pid, "exception": repr(exc)},
            )

    def _cleanup_file_resources(self) -> None:
        if self._log_file:
            try:
                self._log_file.write("===== Logging session ended =====\n")
                self._log_file.flush()
            except Exception:
                pass
            try:
                self._log_file.close()
            except Exception:
                pass
        self._log_file = None
        self._current_log_path = None

    def _status(self, message: str) -> None:
        if not self._status_callback:
            return
        try:
            self._status_callback(message)
        except Exception:
            pass

    def iter_watchers(self) -> Iterable[str]:
        return self._watchers.keys()

