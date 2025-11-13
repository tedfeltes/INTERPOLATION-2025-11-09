"""
Monitoring logic for the launched executable and its related activity.

This monitor polls the target process and surfaces:
  * CPU / memory utilisation
  * Child process creation
  * Loaded modules and open files
  * Database-like file interactions
  * Script executions
  * Network / API usage (via socket connections)
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Callable, Optional, Set, Tuple

import psutil

from app.monitors.base import BaseMonitor


@dataclass
class ProcessMonitorOptions:
    log_process_stats: bool
    log_child_processes: bool
    log_files_and_resources: bool
    log_modules_and_libraries: bool
    log_database_activity: bool
    log_script_activity: bool
    log_network_activity: bool


class ProcessActivityMonitor(BaseMonitor):
    """Polls psutil for process level information according to the configured options."""

    def __init__(self, log_manager, process_supplier: Callable[[], Optional[psutil.Process]], options: ProcessMonitorOptions, interval: float = 1.0) -> None:
        super().__init__("ProcessActivity", log_manager)
        self._process_supplier = process_supplier
        self._options = options
        self._interval = interval
        self._known_children: Set[int] = set()
        self._known_files: Set[str] = set()
        self._known_modules: Set[str] = set()
        self._known_connections: Set[Tuple[str, str, str]] = set()
        self._initialised = False

    def _run(self) -> None:
        poll_delay = min(max(self._interval, 0.5), 5.0)

        while not self.should_stop():
            proc = self._process_supplier()
            if proc is None:
                time.sleep(0.5)
                continue

            if not proc.is_running():
                self.log_event("PROCESS", "Target process has terminated.", {"pid": proc.pid})
                break

            try:
                proc.status()
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                break

            if not self._initialised:
                self._log_initial_snapshot(proc)
                self._initialised = True

            self._log_process_stats(proc)
            self._log_children(proc)
            self._log_open_files(proc)
            self._log_modules(proc)
            self._log_network(proc)

            time.sleep(poll_delay)

    # --- Individual logging helpers --------------------------------------

    def _log_process_stats(self, proc: psutil.Process) -> None:
        if not self._options.log_process_stats:
            return

        try:
            cpu_percent = proc.cpu_percent(interval=None)
            memory_info = proc.memory_info()
            threads = proc.num_threads()
            io_counters = proc.io_counters() if proc.is_running() else None
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            return

        details = {
            "pid": proc.pid,
            "name": proc.name(),
            "status": proc.status(),
            "cpu_percent": cpu_percent,
            "memory": {
                "rss": memory_info.rss,
                "vms": memory_info.vms,
            },
            "threads": threads,
        }
        if io_counters:
            details["io"] = {
                "read_bytes": io_counters.read_bytes,
                "write_bytes": io_counters.write_bytes,
            }

        self.log_event("PROCESS_STATS", "Process resource update.", details)

    def _log_initial_snapshot(self, proc: psutil.Process) -> None:
        try:
            exe = proc.exe()
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            exe = None

        try:
            cmdline = proc.cmdline()
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            cmdline = []

        details = {
            "pid": proc.pid,
            "name": proc.name(),
            "exe": exe,
            "cmdline": cmdline,
            "create_time": proc.create_time(),
        }
        self.log_event("PROCESS", "Monitoring attached to process.", details)

    def _log_children(self, proc: psutil.Process) -> None:
        if not self._options.log_child_processes:
            return

        try:
            children = proc.children(recursive=True)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            return

        current = {child.pid for child in children}
        new_child_pids = current - self._known_children
        terminated = self._known_children - current

        for child in children:
            if child.pid in new_child_pids:
                info = {
                    "pid": child.pid,
                    "name": child.name(),
                    "cmdline": child.cmdline(),
                }
                self.log_event("CHILD_PROCESS", "Child process spawned.", info)

        for pid in terminated:
            self.log_event("CHILD_PROCESS", "Child process terminated.", {"pid": pid})

        self._known_children = current

    def _log_open_files(self, proc: psutil.Process) -> None:
        if not (self._options.log_files_and_resources or self._options.log_database_activity or self._options.log_script_activity):
            return

        try:
            files = proc.open_files()
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            return

        for file in files:
            path = file.path
            if path in self._known_files:
                continue

            self._known_files.add(path)
            self.log_event("FILE_ACCESS", "File handle opened.", {"pid": proc.pid, "path": path})

            lowered = path.lower()
            if self._options.log_database_activity and any(lowered.endswith(ext) for ext in (".db", ".sqlite", ".sqlite3", ".mdb", ".accdb")):
                self.log_event("DATABASE_ACTIVITY", "Database file accessed.", {"pid": proc.pid, "path": path})
            if self._options.log_script_activity and any(lowered.endswith(ext) for ext in (".py", ".ps1", ".bat", ".cmd", ".js", ".vbs")):
                self.log_event("SCRIPT_ACTIVITY", "Script file referenced.", {"pid": proc.pid, "path": path})

    def _log_modules(self, proc: psutil.Process) -> None:
        if not self._options.log_modules_and_libraries:
            return

        try:
            maps = proc.memory_maps()
        except (psutil.NoSuchProcess, psutil.AccessDenied, NotImplementedError):
            return

        for mmap in maps:
            path = getattr(mmap, "path", None)
            if not path:
                continue
            if path in self._known_modules:
                continue
            self._known_modules.add(path)
            self.log_event("MODULE_LOAD", "Module or library mapped into memory.", {"pid": proc.pid, "path": path})

    def _log_network(self, proc: psutil.Process) -> None:
        if not self._options.log_network_activity:
            return

        try:
            connections = proc.net_connections(kind="inet")
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            return

        for conn in connections:
            laddr = f"{conn.laddr.ip}:{conn.laddr.port}" if conn.laddr else "?:?"
            raddr = f"{conn.raddr.ip}:{conn.raddr.port}" if conn.raddr else "local"
            status = conn.status
            signature = (laddr, raddr, status)

            if signature in self._known_connections:
                continue

            self._known_connections.add(signature)
            details = {
                "pid": proc.pid,
                "local": laddr,
                "remote": raddr,
                "status": status,
                "type": str(conn.type),
                "family": str(conn.family),
            }
            self.log_event("NETWORK_ACTIVITY", "Network connection observed.", details)

