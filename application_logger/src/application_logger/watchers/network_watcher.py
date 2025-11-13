"""Monitors network activity for the target process."""
from __future__ import annotations

import socket
import time
from typing import Dict, Tuple

import psutil

from .base import BaseWatcher

DB_PORTS = {
    1433: "mssql",
    1521: "oracle",
    27017: "mongodb",
    3306: "mysql",
    5432: "postgresql",
    6379: "redis",
}

API_PORTS = {
    80: "http",
    443: "https",
    8080: "http-alt",
    8443: "https-alt",
}


class NetworkWatcher(BaseWatcher):
    """Reports new, updated, and closed network connections."""

    def __init__(self, pid: int, log_callback, poll_interval: float = 1.5) -> None:
        super().__init__("network", log_callback)
        self._pid = pid
        self._poll_interval = poll_interval
        self._known_connections: Dict[Tuple, str] = {}

    def run(self) -> None:
        try:
            proc = psutil.Process(self._pid)
        except psutil.NoSuchProcess:
            self.log("lifecycle", "Target process exited before network monitoring started", {"pid": self._pid})
            return
        except psutil.Error as exc:
            self.log("error", "Unable to inspect network connections", {"pid": self._pid, "exception": repr(exc)})
            return

        self.log("status", "Network watcher attached", {"pid": proc.pid})

        while not self.should_stop():
            try:
                connections = proc.connections(kind="inet")
            except psutil.NoSuchProcess:
                self.log("lifecycle", "Target process ended during network polling", {"pid": proc.pid})
                break
            except psutil.AccessDenied as exc:
                self.log("error", "Insufficient privileges to inspect network activity", {"exception": repr(exc)})
                break
            except psutil.Error as exc:
                self.log("error", "Network polling failed", {"exception": repr(exc)})
                break

            current_keys = set()
            for conn in connections:
                conn_id = (conn.fd, conn.family, conn.type, conn.laddr, conn.raddr)
                current_keys.add(conn_id)
                previous_status = self._known_connections.get(conn_id)
                metadata = self._build_metadata(conn)

                if previous_status is None:
                    self._known_connections[conn_id] = conn.status
                    self.log(
                        "connection_opened",
                        "Network connection opened",
                        metadata,
                    )
                elif previous_status != conn.status:
                    self._known_connections[conn_id] = conn.status
                    self.log(
                        "connection_status",
                        f"Connection status changed: {previous_status} -> {conn.status}",
                        metadata,
                    )

            # Closed connections
            for conn_id in list(self._known_connections.keys()):
                if conn_id not in current_keys:
                    last_status = self._known_connections.pop(conn_id)
                    metadata = self._build_metadata_from_id(conn_id, status=last_status)
                    self.log(
                        "connection_closed",
                        "Network connection closed",
                        metadata,
                    )

            time.sleep(self._poll_interval)

        self.log("status", "Network watcher stopped", {"pid": proc.pid})

    def _build_metadata(self, conn: psutil._common.sconn) -> Dict[str, object]:  # type: ignore[attr-defined]
        local_ip, local_port = self._format_addr(conn.laddr)
        remote_ip, remote_port = self._format_addr(conn.raddr)
        protocol = "tcp" if conn.type == socket.SOCK_STREAM else "udp"

        metadata = {
            "pid": self._pid,
            "protocol": protocol,
            "status": conn.status,
            "local_ip": local_ip,
            "local_port": local_port,
            "remote_ip": remote_ip,
            "remote_port": remote_port,
        }

        if remote_port in DB_PORTS:
            metadata["classification"] = "database"
            metadata["target_system"] = DB_PORTS[remote_port]
        elif remote_port in API_PORTS:
            metadata["classification"] = "api"
            metadata["target_system"] = API_PORTS[remote_port]

        return metadata

    def _build_metadata_from_id(self, conn_id: Tuple, status: str) -> Dict[str, object]:
        _, _, sock_type, laddr, raddr = conn_id
        protocol = "tcp" if sock_type == socket.SOCK_STREAM else "udp"
        local_ip, local_port = self._format_addr(laddr)
        remote_ip, remote_port = self._format_addr(raddr)
        metadata = {
            "pid": self._pid,
            "protocol": protocol,
            "status": status,
            "local_ip": local_ip,
            "local_port": local_port,
            "remote_ip": remote_ip,
            "remote_port": remote_port,
        }
        if remote_port in DB_PORTS:
            metadata["classification"] = "database"
            metadata["target_system"] = DB_PORTS[remote_port]
        elif remote_port in API_PORTS:
            metadata["classification"] = "api"
            metadata["target_system"] = API_PORTS[remote_port]
        return metadata

    @staticmethod
    def _format_addr(addr):
        if not addr:
            return None, None
        if isinstance(addr, tuple):
            if len(addr) == 2:
                return addr[0], addr[1]
            if len(addr) == 4:  # IPv6
                return addr[0], addr[1]
        return str(addr), None

