from __future__ import annotations

import socket
from typing import Tuple

import psutil

from .base import BaseMonitor


class NetworkActivityMonitor(BaseMonitor):
    """Report network sockets opened by the target process tree."""

    def __init__(self, emit, poll_interval: float = 1.5) -> None:
        super().__init__("NetworkActivityMonitor", emit, poll_interval=poll_interval)
        self._seen_connections: set[Tuple[int, str, str]] = set()

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
                laddr = self._format_addr(conn.laddr)
                raddr = self._format_addr(conn.raddr)
                signature = (proc.pid, laddr, raddr)
                if signature not in self._seen_connections:
                    self._seen_connections.add(signature)
                    self._emit(
                        f"[Network] pid={proc.pid} fd={conn.fd} status={conn.status} "
                        f"local={laddr} remote={raddr}"
                    )

    @staticmethod
    def _format_addr(addr) -> str:
        if not addr:
            return "N/A"
        host, port = addr
        try:
            host = socket.getfqdn(host)
        except socket.error:
            pass
        return f"{host}:{port}"
