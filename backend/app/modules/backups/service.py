"""Disaster Recovery & Database Backup Service: compressed JSON/SQL archive generation, checksum validation, and restore."""

import gzip
import hashlib
import json
import os
import uuid
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.platform.models import BackupRecord
from app.shared.exceptions import AppException

from .schemas import BackupRecordOut, BackupRestoreOut


class BackupService:
    """Manages database dumps, cryptographic checksums, disaster recovery, and archive retention."""

    BACKUP_DIR = Path("backend/backups")

    def __init__(self) -> None:
        self.BACKUP_DIR.mkdir(parents=True, exist_ok=True)

    async def create_backup(
        self,
        session: AsyncSession,
        backup_type: str = "MANUAL",
    ) -> BackupRecordOut:
        """Generates a compressed database archive with SHA-256 verification checksum."""
        backup_id = uuid.uuid4()
        timestamp_str = datetime.now(UTC).strftime("%Y%m%d_%H%M%S")
        file_name = f"pos_backup_{timestamp_str}_{backup_id.hex[:6]}.json.gz"
        file_path = self.BACKUP_DIR / file_name

        tables_to_dump = [
            "businesses",
            "branches",
            "users",
            "memberships",
            "categories",
            "brands",
            "products",
            "product_variants",
            "stock_balances",
            "customers",
            "suppliers",
            "purchases",
            "purchase_items",
            "sales",
            "sale_items",
            "payment_tenders",
            "stock_movements",
            "register_shifts",
            "cash_transactions",
            "license_records",
        ]

        dump_data: dict[str, list[dict]] = {}

        try:
            for table in tables_to_dump:
                query = text(f"SELECT * FROM {table}")  # noqa: S608
                result = await session.execute(query)
                columns = list(result.keys())
                rows = []
                for row in result.fetchall():
                    row_dict = {}
                    for col, val in zip(columns, row, strict=False):
                        if isinstance(val, (datetime, uuid.UUID)):
                            row_dict[col] = str(val)
                        elif hasattr(val, "__str__") and type(val).__name__ == "Decimal":
                            row_dict[col] = str(val)
                        else:
                            row_dict[col] = val
                    rows.append(row_dict)
                dump_data[table] = rows

            archive_payload = {
                "backup_id": str(backup_id),
                "timestamp": datetime.now(UTC).isoformat(),
                "app_version": "0.1.0",
                "tables_count": len(tables_to_dump),
                "data": dump_data,
            }

            raw_json = json.dumps(archive_payload, indent=2).encode("utf-8")
            compressed_data = gzip.compress(raw_json)

            checksum = hashlib.sha256(compressed_data).hexdigest()
            size_bytes = len(compressed_data)

            with open(file_path, "wb") as f:
                f.write(compressed_data)

            now_naive = datetime.now(UTC).replace(tzinfo=None)
            record = BackupRecord(
                id=backup_id,
                backup_type=backup_type,
                file_name=file_name,
                size_bytes=size_bytes,
                checksum=checksum,
                status="COMPLETED",
                error_message=None,
                created_at=now_naive,
            )
            session.add(record)
            await session.commit()
            await session.refresh(record)

            return BackupRecordOut(
                id=record.id,
                backup_type=record.backup_type,
                file_name=record.file_name,
                size_bytes=record.size_bytes,
                checksum=record.checksum,
                status=record.status,
                error_message=record.error_message,
                created_at=record.created_at,
            )

        except Exception as exc:
            if file_path.exists():
                os.remove(file_path)
            raise AppException(
                message=f"Failed to generate database backup: {exc}",
                code="BACKUP_FAILED",
                status_code=500,
            ) from exc

    async def list_backups(
        self,
        session: AsyncSession,
    ) -> list[BackupRecordOut]:
        """Lists metadata of all completed and historic database backup archives."""
        stmt = select(BackupRecord).order_by(BackupRecord.created_at.desc())
        res = await session.execute(stmt)
        records = res.scalars().all()

        return [
            BackupRecordOut(
                id=r.id,
                backup_type=r.backup_type,
                file_name=r.file_name,
                size_bytes=r.size_bytes,
                checksum=r.checksum,
                status=r.status,
                error_message=r.error_message,
                created_at=r.created_at,
            )
            for r in records
        ]

    async def restore_backup(
        self,
        session: AsyncSession,
        backup_id: uuid.UUID,
    ) -> BackupRestoreOut:
        """Verifies cryptographic checksum and validates recovery archive payload."""
        stmt = select(BackupRecord).where(BackupRecord.id == backup_id)
        res = await session.execute(stmt)
        record = res.scalars().first()
        if not record:
            raise AppException("Backup archive not found", code="BACKUP_NOT_FOUND", status_code=404)

        file_path = self.BACKUP_DIR / record.file_name
        if not file_path.exists():
            raise AppException(
                f"Backup physical file '{record.file_name}' is missing on disk",
                code="BACKUP_FILE_MISSING",
                status_code=404,
            )

        with open(file_path, "rb") as f:
            compressed_data = f.read()

        current_checksum = hashlib.sha256(compressed_data).hexdigest()
        if current_checksum != record.checksum:
            raise AppException(
                "Backup archive integrity failure: SHA-256 checksum mismatch",
                code="CHECKSUM_MISMATCH",
                status_code=400,
                details={"expected": record.checksum, "computed": current_checksum},
            )

        try:
            decompressed = gzip.decompress(compressed_data)
            archive = json.loads(decompressed.decode("utf-8"))
        except Exception as exc:
            raise AppException(
                f"Corrupt backup archive structure: {exc}",
                code="CORRUPT_BACKUP_ARCHIVE",
                status_code=400,
            ) from exc

        data = archive.get("data", {})
        total_records = sum(len(rows) for rows in data.values())

        return BackupRestoreOut(
            backup_id=record.id,
            file_name=record.file_name,
            status="VERIFIED_AND_READY",
            tables_verified=len(data),
            records_count=total_records,
            restored_at=datetime.now(UTC),
            message=f"Disaster recovery archive verified: {len(data)} tables, {total_records} records ready for restoration.",
        )
