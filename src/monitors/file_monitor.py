from __future__ import annotations

import psutil

from .base import BaseMonitor


class FileActivityMonitor(BaseMonitor):
    """Report files opened by the target process and its children."""

    def __init__(self, emit, poll_interval: float = 1.5) -> None:
        super().__init__("FileActivityMonitor", emit, poll_interval=poll_interval)
        self._seen_paths: set[str] = set()

    def poll(self, pid: int) -> None:
        try:
            process = psutil.Process(pid)
        except psutil.NoSuchProcess:
            self.stop()
            return

        processes = [process] + process.children(recursive=True)
        for proc in processes:
            try:
                for handle in proc.open_files():
                    path = handle.path
                    if path not in self._seen_paths:
                        self._seen_paths.add(path)
                        self._emit(
                            f"[File] pid={proc.pid} accessed {path} (mode={handle.mode}, flags={handle.flags})"
                        )
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
