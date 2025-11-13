"""
Coordinator responsible for instantiating and controlling monitor components.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional

import psutil

from app.logger import LogManager
from app.monitors.base import BaseMonitor
from app.monitors.input_monitor import UserInputMonitor
from app.monitors.process_monitor import ProcessActivityMonitor, ProcessMonitorOptions


@dataclass
class LogOptions:
    """Options toggled by the user to select which data streams to record."""

    user_input: bool = True
    process_stats: bool = True
    child_processes: bool = True
    files_and_resources: bool = True
    modules_and_libraries: bool = True
    database_activity: bool = True
    script_activity: bool = True
    network_activity: bool = True


class MonitorManager:
    """Creates and manages monitor instances based on the selected log options."""

    def __init__(self, log_manager: LogManager) -> None:
        self._log_manager = log_manager
        self._monitors: List[BaseMonitor] = []
        self._options = LogOptions()
        self._target_pid: Optional[int] = None
        self._psutil_process: Optional[psutil.Process] = None

    def configure(self, options: LogOptions) -> None:
        self._options = options

    def attach_process(self, pid: Optional[int]) -> None:
        self._target_pid = pid
        self._psutil_process = None

    def start_monitors(self) -> None:
        self.stop_monitors()
        monitors: List[BaseMonitor] = []

        if self._options.user_input:
            monitors.append(UserInputMonitor(self._log_manager))

        if self._requires_process_monitoring():
            process_options = ProcessMonitorOptions(
                log_process_stats=self._options.process_stats,
                log_child_processes=self._options.child_processes,
                log_files_and_resources=self._options.files_and_resources,
                log_modules_and_libraries=self._options.modules_and_libraries,
                log_database_activity=self._options.database_activity,
                log_script_activity=self._options.script_activity,
                log_network_activity=self._options.network_activity,
            )
            monitors.append(ProcessActivityMonitor(self._log_manager, self._get_process, process_options))

        self._monitors = monitors
        for monitor in self._monitors:
            monitor.start()

    def stop_monitors(self) -> None:
        for monitor in self._monitors:
            monitor.stop()
        self._monitors = []

    def _requires_process_monitoring(self) -> bool:
        return any(
            [
                self._options.process_stats,
                self._options.child_processes,
                self._options.files_and_resources,
                self._options.modules_and_libraries,
                self._options.database_activity,
                self._options.script_activity,
                self._options.network_activity,
            ]
        )

    def _get_process(self) -> Optional[psutil.Process]:
        if self._target_pid is None:
            return None
        if self._psutil_process and self._psutil_process.is_running():
            return self._psutil_process
        try:
            proc = psutil.Process(self._target_pid)
        except psutil.NoSuchProcess:
            return None
        self._psutil_process = proc
        return proc

