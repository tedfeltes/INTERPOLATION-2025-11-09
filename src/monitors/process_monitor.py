from __future__ import annotations

import psutil

from .base import BaseMonitor


class ProcessTreeMonitor(BaseMonitor):
    """Track the lifecycle of the target process and its children."""

    def __init__(self, emit, poll_interval: float = 1.0) -> None:
        super().__init__("ProcessTreeMonitor", emit, poll_interval=poll_interval)
        self._known_pids: set[int] = set()

    def poll(self, pid: int) -> None:
        try:
            process = psutil.Process(pid)
        except psutil.NoSuchProcess:
            self._emit("[Process] Target process has exited.")
            self.stop()
            return

        if pid not in self._known_pids:
            self._known_pids.add(pid)
            self._emit(
                f"[Process] Root process started: pid={pid}, name={process.name()}, cmdline={' '.join(process.cmdline())}"
            )

        self._log_children(process)
        self._log_threads(process)

    def _log_children(self, process: psutil.Process) -> None:
        current_children = set()
        try:
            for child in process.children(recursive=True):
                current_children.add(child.pid)
                if child.pid not in self._known_pids:
                    self._known_pids.add(child.pid)
                    cmd = " ".join(child.cmdline()) if child.cmdline() else child.name()
                    self._emit(
                        f"[Process] Child started: pid={child.pid}, name={child.name()}, cmdline={cmd}"
                    )
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            return

        exited = [
            known_pid for known_pid in list(self._known_pids) if known_pid not in current_children
        ]
        for pid in exited:
            if pid == process.pid:
                continue
            if not psutil.pid_exists(pid):
                self._known_pids.discard(pid)
                self._emit(f"[Process] Child exited: pid={pid}")

    def _log_threads(self, process: psutil.Process) -> None:
        try:
            threads = process.threads()
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            return

        thread_info = ", ".join(f"id={t.id} user={t.user_time:.3f}s" for t in threads[:10])
        self._emit(f"[Process] Thread snapshot: count={len(threads)} [{thread_info}]")
