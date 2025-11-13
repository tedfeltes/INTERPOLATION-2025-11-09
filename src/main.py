from gui import MainWindow
from services import LoggingController, MonitorConfig  # re-export for convenience

__all__ = ["MainWindow", "LoggingController", "MonitorConfig"]

if __name__ == "__main__":
    from gui.main_window import run_application

    raise SystemExit(run_application())
