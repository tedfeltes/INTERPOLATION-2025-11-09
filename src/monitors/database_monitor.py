from __future__ import annotations

from typing import Dict

import psutil

from .base import BaseMonitor

KNOWN_DATABASE_PORTS: Dict[int, str] = {
    1433: "Microsoft SQL Server",
    1521: "Oracle Database",
    27017: "MongoDB",
    3306: "MySQL/MariaDB",
    5432: "PostgreSQL",
    6379: "Redis",
    6380: "Redis TLS",
    9200: "Elasticsearch",
    11211: "Memcached",
}


class DatabaseActivityMonitor(BaseMonitor):
    """Identify outbound connections that likely target database services."""

    def __init__(self, emit, poll_interval: float = 2.0) -> None:
        super().__init__("DatabaseActivityMonitor", emit, poll_interval=poll_interval)
        self._seen: set[tuple[int, int]] = set()

    def poll(self, pid: int) -> None:
        try:
            process = psutil.Process(pid)
        except psutil.NoSuchProcess:
            self.stop()
            return

        processes = [process] + process.children(recursive=True)
        for proc in processes:
            try:
                connections = proc.connections(kind="inet")
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue

            for conn in connections:
                raddr = conn.raddr
                if not raddr:
                    continue
                port = raddr.port
                if port in KNOWN_DATABASE_PORTS:
                    signature = (proc.pid, port)
                    if signature not in self._seen:
                        self._seen.add(signature)
                        label = KNOWN_DATABASE_PORTS[port]
                        self._emit(
                            f"[Database] pid={proc.pid} connected to {raddr.ip}:{port} ({label})"
                        )
