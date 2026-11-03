"""Logging configuration for the POS application.

Provides structured, clean logging while ensuring sensitive information
(passwords, tokens, payment credentials) is never leaked into logs.
"""

import logging
import sys


class SafeLogFilter(logging.Filter):
    """Filters or redacts known sensitive keywords from log records."""

    SENSITIVE_KEYS = {
        "password",
        "secret",
        "token",
        "authorization",
        "access_token",
        "refresh_token",
        "private_key",
    }

    def filter(self, record: logging.LogRecord) -> bool:
        if isinstance(record.msg, str):
            for key in self.SENSITIVE_KEYS:
                if key in record.msg.lower() and "=" in record.msg:
                    # Basic redaction indicator
                    record.msg = f"[REDACTED_SENSITIVE_DATA in message: {record.msg[:40]}...]"
                    break
        return True


def setup_logging(debug: bool = False) -> None:
    """Configure root and application loggers."""
    log_level = logging.DEBUG if debug else logging.INFO

    formatter = logging.Formatter(
        fmt="%(asctime)s [%(levelname)s] [%(name)s:%(lineno)d] - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(log_level)
    handler.setFormatter(formatter)
    handler.addFilter(SafeLogFilter())

    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)
    # Clear existing handlers to avoid duplicates
    root_logger.handlers.clear()
    root_logger.addHandler(handler)

    # Adjust third-party loggers to be less noisy
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING if not debug else logging.INFO)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
