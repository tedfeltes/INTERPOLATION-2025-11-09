from __future__ import annotations

import threading
from typing import Callable, Optional


class ETWSession:
    """Lightweight wrapper for an ETW session targeting Win32 API activity.

    This implementation requires the third-party ``python-etw`` package. If it is not
    available, :meth:`setup` will raise a :class:`RuntimeError` describing the required
    steps so that the caller can relay the information to the user.
    """

    def __init__(self, pid: int, emit: Callable[[str], None]) -> None:
        self._pid = pid
        self._emit = emit
        self._etw: Optional["ETW"] = None
        self._thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()

    def setup(self) -> None:
        try:
            from etw import ETW, TraceEvent  # type: ignore
            from etw.providers.kernel import KernelTraceProvider  # type: ignore
        except ImportError as exc:  # pragma: no cover - optional dependency
            raise RuntimeError(
                "python-etw package is required for API tracing. "
                "Install it with 'pip install python-etw' from an elevated PowerShell "
                "prompt on Windows."
            ) from exc

        provider = KernelTraceProvider()
        provider.any = 0x10  # Process/Thread/Module load events

        def callback(event: TraceEvent) -> None:  # pragma: no cover - requires Windows
            pid = event.event_header.process_id
            if pid != self._pid:
                return
            api = event.event_descriptor.opcode
            self._emit(
                f"[API] evt={event.event_name} opcode={api} "
                f"id={event.event_descriptor.id} version={event.event_descriptor.version}"
            )

        self._etw = ETW(
            providers=[provider],
            event_callback=callback,
            ring_buffer_size=1024,
            session_name="ApiCallTraceSession",
        )

    def start_tracing(self) -> None:
        if not self._etw or self._thread:
            return

        def _worker() -> None:  # pragma: no cover - requires Windows
            self._etw.start()
            while not self._stop_event.is_set():
                self._etw.process()
            self._etw.stop()

        self._stop_event.clear()
        self._thread = threading.Thread(target=_worker, name="ETWSession", daemon=True)
        self._thread.start()

    def stop_tracing(self) -> None:
        if not self._thread:
            return
        self._stop_event.set()
        self._thread.join(timeout=2.0)
        self._thread = None

    def flush_buffer(self) -> None:
        if self._etw:
            try:
                self._etw.process()
            except Exception:  # pragma: no cover - defensive
                pass

    def dispose(self) -> None:
        self.stop_tracing()
        if self._etw:
            try:
                self._etw.stop()
            except Exception:  # pragma: no cover - defensive
                pass
            self._etw = None
