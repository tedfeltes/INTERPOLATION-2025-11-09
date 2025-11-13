from __future__ import annotations

import psutil

from .base import BaseMonitor


class ResourceUsageMonitor(BaseMonitor):
    """Capture CPU, memory, handle count, and IO stats."""

    def __init__(self, emit, poll_interval: float = 1.0) -> None:
        super().__init__("ResourceUsageMonitor", emit, poll_interval=poll_interval)

    def poll(self, pid: int) -> None:
        try:
            process = psutil.Process(pid)
        except psutil.NoSuchProcess:
            self.stop()
            return

        try:
            cpu = process.cpu_percent(interval=None)
            mem = process.memory_info()
            io = process.io_counters()
            handles = process.num_handles() if hasattr(process, "num_handles") else "n/a"
            threads = process.num_threads()
            self._emit(
                "[Resource] cpu={cpu:.1f}% rss={rss} vms={vms} io_read={rd} io_write={wr} "
                "handles={handles} threads={threads}".format(
                    cpu=cpu,
                    rss=mem.rss,
                    vms=mem.vms,
                    rd=getattr(io, "read_bytes", 0),
                    wr=getattr(io, "write_bytes", 0),
                    handles=handles,
                    threads=threads,
                )
            )
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            self.stop()
