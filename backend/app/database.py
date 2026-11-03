"""SQLAlchemy 2.x async database engine and session management."""

import logging
from collections.abc import AsyncGenerator

from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.config import get_settings

logger = logging.getLogger(__name__)


class Base(DeclarativeBase):
    """Base declarative class for all SQLAlchemy ORM models."""

    pass


_engine: AsyncEngine | None = None
_session_maker: async_sessionmaker[AsyncSession] | None = None


def get_engine() -> AsyncEngine:
    """Returns or creates the global async SQLAlchemy engine."""
    global _engine
    if _engine is None:
        settings = get_settings()
        if settings.ENVIRONMENT == "testing":
            from sqlalchemy import pool

            _engine = create_async_engine(
                settings.get_database_url(),
                echo=settings.DEBUG,
                poolclass=pool.NullPool,
                connect_args={"timeout": 5.0},
            )
        else:
            _engine = create_async_engine(
                settings.get_database_url(),
                echo=settings.DEBUG,
                pool_pre_ping=True,
                pool_size=10,
                max_overflow=20,
                connect_args={"timeout": 10.0},
            )
    return _engine


def get_session_maker() -> async_sessionmaker[AsyncSession]:
    """Returns the async sessionmaker."""
    global _session_maker
    if _session_maker is None:
        _session_maker = async_sessionmaker(
            bind=get_engine(),
            autocommit=False,
            autoflush=False,
            expire_on_commit=False,
        )
    return _session_maker


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency that yields an async database session."""
    session_factory = get_session_maker()
    async with session_factory() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def close_db_connection() -> None:
    """Disposes the engine only if it was initialized."""
    global _engine, _session_maker
    if _engine is not None:
        await _engine.dispose()
        _engine = None
        _session_maker = None


async def check_db_health() -> bool:
    """Verifies database connectivity without leaking connection details or credentials."""
    try:
        import asyncio

        async def _ping() -> bool:
            engine = get_engine()
            async with engine.connect() as conn:
                result = await conn.execute(text("SELECT 1"))
                return result.scalar() == 1

        return await asyncio.wait_for(_ping(), timeout=3.0)
    except Exception as e:
        logger.warning(f"Database health check failed: {type(e).__name__}")
        return False
