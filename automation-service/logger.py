import logging
import logging.handlers
import os
from pathlib import Path

def setup_logging(log_dir: str = "logs", log_file: str = "app.log", log_level: int = logging.INFO):
    """
    Setup centralized logging with rotation and console output.
    """
    # Ensure log directory exists
    Path(log_dir).mkdir(parents=True, exist_ok=True)
    log_path = os.path.join(log_dir, log_file)

    # Create formatters
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

    # Handler for file (Rotating)
    # 10MB max size, keep 5 backups
    file_handler = logging.handlers.RotatingFileHandler(
        log_path, maxBytes=10*1024*1024, backupCount=5, encoding='utf-8'
    )
    file_handler.setFormatter(formatter)
    file_handler.setLevel(log_level)

    # Handler for console
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    console_handler.setLevel(log_level)

    # Configure root logger
    logging.basicConfig(
        level=log_level,
        handlers=[file_handler, console_handler],
        force=True  # Overwrite any existing configuration
    )

    # Log that logging is set up
    logging.getLogger(__name__).info(f"Logging configured. Writing to {log_path}")
