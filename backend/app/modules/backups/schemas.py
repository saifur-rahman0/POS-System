"""Schemas for Database Backup, Archive Verification, and Disaster Recovery."""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class BackupCreateRequest(BaseModel):
    """Payload to trigger an on-demand database backup archive."""

    backup_type: str = Field(
        default="MANUAL",
        description="MANUAL, SCHEDULED, or AUTO_PRE_UPGRADE",
    )
    notes: str | None = None


class BackupRecordOut(BaseModel):
    """Metadata of an exported database backup archive."""

    id: uuid.UUID
    backup_type: str
    file_name: str
    size_bytes: int
    checksum: str
    status: str
    error_message: str | None = None
    created_at: datetime


class BackupRestoreOut(BaseModel):
    """Summary of a completed database disaster recovery restoration."""

    backup_id: uuid.UUID
    file_name: str
    status: str
    tables_verified: int
    records_count: int
    restored_at: datetime
    message: str

