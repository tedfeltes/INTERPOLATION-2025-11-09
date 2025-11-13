"""Process tree and resource usage monitoring."""
from __future__ import annotations

import time
from typing import Dict, Optional

import psutil

from .base import BaseWatcher


class ProcessWatcher(BaseWatcher):
    """Observes the target process, its resource usage, and child processes."""

    def __init__(
        self,
        pid: int,
        log_callback,
        track_children: bool = True,
        track_resources: bool = True,
        poll_interval: float = 1.0,
    ) -> None:
        super().__init__("process", log_callback)
        self._pid = pid
        self._track_children = track_children
        self._track_resources = track_resources
        self._poll_interval = poll_interval
        self._known_children: Dict[int, Dict[str, Optional[str]]] = {}

    def run(self) -> None:
        try:
            proc = psutil.Process(self._pid)
        except psutil.NoSuchProcess:
            self.log("lifecycle", "Target process exited before monitoring started", {"pid": self._pid})
            return
        except psutil.Error as exc:
            self.log("error", "Unable to attach to target process", {"pid": self._pid, "exception": repr(exc)})
            return

        self.log(
            "lifecycle",
            "Process watcher attached",
            {
                "pid": proc.pid,
                "name": safe_call(proc.name),
                "exe": safe_call(proc.exe),
                "status": safe_call(proc.status),
            },
        )

        try:
            proc.cpu_percent(interval=None)  # prime CPU measurement
        except psutil.Error:
            pass

        while not self.should_stop():
            if not proc.is_running():
                self.log("lifecycle", "Target process no longer running", {"pid": proc.pid})
                break

            if self._track_resources:
                self._collect_resources(proc)

            if self._track_children:
                self._collect_children(proc)

            time.sleep(self._poll_interval)

        self.log("status", "Process watcher stopped", {"pid": proc.pid})

    def _collect_resources(self, proc: psutil.Process) -> None:
        try:
            cpu = proc.cpu_percent(interval=None)
            mem = proc.memory_info()
            threads = proc.num_threads()
            handles = getattr(proc, "num_handles", lambda: None)
            handle_count = handles() if callable(handles) else handles
            io_counters = None
            try:
                io_counters = proc.io_counters()
            except psutil.Error:
                pass

            metadata = {
                "pid": proc.pid,
                "cpu_percent": cpu,
                "rss_bytes": getattr(mem, "rss", None),
                "vms_bytes": getattr(mem, "vms", None),
                "num_threads": threads,
            }
            if handle_count is not None:
                metadata["handle_count"] = handle_count
            if io_counters:
                metadata.update(
                    {
                        "read_bytes": getattr(io_counters, "read_bytes", None),
                        "write_bytes": getattr(io_counters, "write_bytes", None),
                    }
                )

            self.log(
                "resource_snapshot",
                "Resource usage sample",
                metadata,
            )
        except psutil.NoSuchProcess:
            self.log("lifecycle", "Target process terminated during resource polling", {"pid": proc.pid})
            self._stop_event.set()
        except psutil.Error as exc:
            self.log("error", "Failed to query process resources", {"pid": proc.pid, "exception": repr(exc)})

    def _collect_children(self, proc: psutil.Process) -> None:
        try:
            current_children = {child.pid: child for child in proc.children(recursive=True)}
        except psutil.Error as exc:
            self.log("error", "Failed to enumerate child processes", {"pid": proc.pid, "exception": repr(exc)})
            return

        # Detect new child processes
        for pid, child in current_children.items():
            if pid in self._known_children:
                continue
            info = {
                "pid": child.pid,
                "name": safe_call(child.name),
                "exe": safe_call(child.exe),
                "cmdline": safe_call(child.cmdline),
                "ppid": child.ppid(),
                "create_time": safe_call(child.create_time),
            }
            self._known_children[pid] = {
                "name": info["name"],
                "cmdline": " ".join(info.get("cmdline") or []),
            }
            self.log("child_started", f"Child process spawned: {info['name']} ({pid})", info)

        # Detect terminated children
        previous_pids = set(self._known_children.keys())
        current_pids = set(current_children.keys())
        for pid in previous_pids - current_pids:
            child_info = self._known_children.pop(pid, None)
            if child_info:
                self.log(
                    "child_terminated",
                    f"Child process ended: {child_info.get('name') or pid}",
                    {"pid": pid, "cmdline": child_info.get("cmdline")},
                )


def safe_call(callable_or_value):
    try:
        if callable(callable_or_value):
            return callable_or_value()
        return callable_or_value
    except Exception:
        return None

