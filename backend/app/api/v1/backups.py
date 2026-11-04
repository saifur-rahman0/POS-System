"""Database Backup and Disaster Recovery API endpoints."""

import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.backups.schemas import (
    BackupCreateRequest,
    BackupRecordOut,
    BackupRestoreOut,
)
from app.modules.backups.service import BackupService
from app.shared.auth import CurrentUser, require_permission

router = APIRouter(prefix="/backups", tags=["Disaster Recovery & Database Backups"])
backup_service = BackupService()


@router.get(
    "",
    response_model=list[BackupRecordOut],
    summary="List database backup archives and verification status",
)
async def list_backups(
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> list[BackupRecordOut]:
    """Retrieves metadata of local database backup archives."""
    return await backup_service.list_backups(session=db)


@router.post(
    "/create",
    response_model=BackupRecordOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new compressed database backup archive",
)
async def create_backup(
    payload: BackupCreateRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> BackupRecordOut:
    """Exports all operational tables to a gzip-compressed archive with SHA-256 checksum."""
    return await backup_service.create_backup(
        session=db,
        backup_type=payload.backup_type,
    )


@router.post(
    "/{backup_id}/restore",
    response_model=BackupRestoreOut,
    summary="Verify archive integrity and restore database from backup",
)
async def restore_backup(
    backup_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("admin")),
) -> BackupRestoreOut:
    """Validates cryptographic checksum and checks disaster recovery payload readiness."""
    return await backup_service.restore_backup(
        session=db,
        backup_id=backup_id,
    )

