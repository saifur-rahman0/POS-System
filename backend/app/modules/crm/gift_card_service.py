"""Security, hashing, and alphanumeric code generation for Gift Cards and Credit Notes."""

import hashlib
import secrets
from datetime import datetime


class GiftCardService:
    """Utilities for issuing gift cards, hashing PINs, and verifying credentials."""

    @staticmethod
    def generate_card_number(prefix: str = "GC") -> str:
        """Generate a random 16-character card number in format: GC-XXXX-XXXX-XXXX."""
        chars = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"  # Exclude ambiguous 0, 1, I, O
        part1 = "".join(secrets.choice(chars) for _ in range(4))
        part2 = "".join(secrets.choice(chars) for _ in range(4))
        part3 = "".join(secrets.choice(chars) for _ in range(4))
        return f"{prefix}-{part1}-{part2}-{part3}"

    @staticmethod
    def generate_credit_note_number(prefix: str = "CN") -> str:
        """Generate sequential/random credit note number: CN-YYYYMMDD-XXXX."""
        date_str = datetime.utcnow().strftime("%Y%m%d")
        chars = "0123456789ABCDEF"
        suffix = "".join(secrets.choice(chars) for _ in range(4))
        return f"{prefix}-{date_str}-{suffix}"

    @staticmethod
    def hash_pin(raw_pin: str, salt: str | None = None) -> str:
        """Hash a numeric PIN using SHA-256 with a random 16-byte cryptographic salt.

        Returns string in format: salt$hash
        """
        if not raw_pin or len(raw_pin) < 4:
            raise ValueError("PIN must be at least 4 digits")

        if salt is None:
            salt = secrets.token_hex(16)

        digest = hashlib.sha256(f"{salt}:{raw_pin}".encode()).hexdigest()
        return f"{salt}${digest}"

    @staticmethod
    def verify_pin(stored_pin_hash: str, raw_pin: str) -> bool:
        """Verify candidate raw PIN against stored salt$hash representation."""
        if "$" not in stored_pin_hash:
            return False

        salt, expected_digest = stored_pin_hash.split("$", 1)
        actual_digest = hashlib.sha256(f"{salt}:{raw_pin}".encode()).hexdigest()
        return secrets.compare_digest(actual_digest, expected_digest)
