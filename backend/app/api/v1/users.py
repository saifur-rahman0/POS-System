"""Staff & User Access Management API endpoints."""

import logging
import uuid
from typing import Any

import argon2
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.modules.identity.models import Membership, MembershipRole, Permission, Role, RolePermission, User
from app.shared.auth import CurrentUser, get_current_user, require_permission
from app.shared.roles import ROLE_LABELS, ROLE_PERMISSIONS, SYSTEM_PERMISSIONS

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/users", tags=["Users & Staff Permissions"])

ph = argon2.PasswordHasher()


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class UserProfileOut(BaseModel):
    id: uuid.UUID
    username: str
    display_name: str
    email: str | None = None
    phone: str | None = None
    is_active: bool = True
    role: str = "CASHIER"
    role_label: str = "Cashier"
    permissions: list[str] = Field(default_factory=list)


class CreateUserRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=100, description="Unique login username")
    password: str = Field(..., min_length=4, max_length=128, description="Login password")
    display_name: str = Field(..., min_length=2, max_length=255, description="Full name or nickname")
    email: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=50)
    role: str = Field(default="CASHIER", description="ADMIN, MANAGER, CASHIER, or STOCK_KEEPER")
    custom_permissions: list[str] | None = Field(default=None, description="Optional override list of permissions")


class UpdateUserRequest(BaseModel):
    display_name: str | None = Field(default=None, min_length=2, max_length=255)
    email: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=50)
    role: str | None = Field(default=None, description="ADMIN, MANAGER, CASHIER, or STOCK_KEEPER")
    is_active: bool | None = None
    custom_permissions: list[str] | None = None


class ChangeUserPasswordRequest(BaseModel):
    new_password: str = Field(..., min_length=4, max_length=128, description="New password")


class RolesMetaResponse(BaseModel):
    roles: dict[str, list[str]]
    permissions: dict[str, str]
    labels: dict[str, str]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _resolve_user_role_and_permissions(
    session: AsyncSession,
    business_id: uuid.UUID,
    user: User,
) -> tuple[str, list[str]]:
    """Resolves primary role and effective permissions for a user in a given business."""
    # Check membership and roles
    m_stmt = (
        select(Membership)
        .options(selectinload(Membership.roles).selectinload(Role.permissions))
        .where(
            Membership.business_id == business_id,
            Membership.user_id == user.id,
            Membership.status == "ACTIVE",
        )
    )
    m_res = await session.execute(m_stmt)
    membership = m_res.scalars().first()

    if membership and membership.roles:
        primary_role = membership.roles[0].name.upper()
        # Collect permissions from DB role_permissions
        db_perms = [p.code for p in membership.roles[0].permissions]
        if not db_perms:
            db_perms = ROLE_PERMISSIONS.get(primary_role, ROLE_PERMISSIONS.get("CASHIER", []))
        return primary_role, db_perms

    # Fallback by username conventions
    uname = user.username.lower()
    if uname in ("admin", "dev_admin", "owner", "stall_owner"):
        return "ADMIN", ROLE_PERMISSIONS["ADMIN"]
    elif uname in ("manager", "dev_manager", "store_manager"):
        return "MANAGER", ROLE_PERMISSIONS["MANAGER"]
    elif uname in ("stock_keeper", "stock", "warehouse"):
        return "STOCK_KEEPER", ROLE_PERMISSIONS["STOCK_KEEPER"]
    else:
        return "CASHIER", ROLE_PERMISSIONS["CASHIER"]


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@router.get(
    "/meta/roles",
    response_model=RolesMetaResponse,
    summary="Get standard roles catalog and permissions list",
)
async def get_roles_meta() -> Any:
    """Returns available role keys, permission descriptions, and human-friendly labels."""
    return RolesMetaResponse(
        roles=ROLE_PERMISSIONS,
        permissions=SYSTEM_PERMISSIONS,
        labels=ROLE_LABELS,
    )


@router.get(
    "",
    response_model=list[UserProfileOut],
    summary="List all users and staff in current store",
)
async def list_users(
    current_user: CurrentUser = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> Any:
    """Retrieves all active and inactive users associated with the current business."""
    # Find all users having memberships with this business
    stmt = (
        select(User)
        .join(Membership, Membership.user_id == User.id)
        .where(Membership.business_id == current_user.business_id)
        .order_by(User.created_at.asc())
    )
    res = await session.execute(stmt)
    users = list(res.scalars().all())

    # If empty or only dev account, also include dev accounts if in dev environment
    if not users:
        stmt_fallback = select(User).order_by(User.created_at.asc()).limit(20)
        res_fb = await session.execute(stmt_fallback)
        users = list(res_fb.scalars().all())

    result: list[UserProfileOut] = []
    for u in users:
        role_name, perms = await _resolve_user_role_and_permissions(
            session, current_user.business_id, u
        )
        result.append(
            UserProfileOut(
                id=u.id,
                username=u.username,
                display_name=u.display_name,
                email=u.email,
                phone=u.phone,
                is_active=u.is_active,
                role=role_name,
                role_label=ROLE_LABELS.get(role_name, role_name),
                permissions=perms,
            )
        )
    return result


@router.post(
    "",
    response_model=UserProfileOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new staff user and assign role/permissions",
)
async def create_user(
    payload: CreateUserRequest,
    current_user: CurrentUser = Depends(require_permission("users:manage")),
    session: AsyncSession = Depends(get_db),
) -> Any:
    """Creates a new user record, associates it with business membership, and assigns role."""
    # 1. Validate username uniqueness
    u_stmt = select(User).where(User.username == payload.username.strip())
    existing = (await session.execute(u_stmt)).scalars().first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Username '{payload.username}' is already in use.",
        )

    if payload.email:
        em_stmt = select(User).where(User.email == payload.email.strip())
        existing_email = (await session.execute(em_stmt)).scalars().first()
        if existing_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Email '{payload.email}' is already registered.",
            )

    # 2. Hash password with argon2id
    hashed = ph.hash(payload.password)

    role_key = payload.role.strip().upper()
    if role_key not in ROLE_PERMISSIONS:
        role_key = "CASHIER"

    new_user = User(
        username=payload.username.strip(),
        display_name=payload.display_name.strip(),
        password_hash=hashed,
        email=payload.email.strip() if payload.email else None,
        phone=payload.phone.strip() if payload.phone else None,
        is_active=True,
    )
    session.add(new_user)
    await session.flush()

    # 3. Create Business Membership
    membership = Membership(
        business_id=current_user.business_id,
        user_id=new_user.id,
        status="ACTIVE",
    )
    session.add(membership)
    await session.flush()

    # 4. Resolve or create Role for business
    role_stmt = select(Role).where(
        or_(
            Role.business_id == current_user.business_id,
            Role.business_id.is_(None),
        ),
        Role.name == role_key,
    )
    role_obj = (await session.execute(role_stmt)).scalars().first()
    if not role_obj:
        role_obj = Role(
            business_id=current_user.business_id,
            name=role_key,
            description=ROLE_LABELS.get(role_key, role_key),
        )
        session.add(role_obj)
        await session.flush()

    # Link Membership to Role
    mr = MembershipRole(
        membership_id=membership.id,
        role_id=role_obj.id,
    )
    session.add(mr)

    # Effective permissions
    perms = payload.custom_permissions or ROLE_PERMISSIONS.get(role_key, ["pos", "sales:create"])

    await session.commit()
    await session.refresh(new_user)

    logger.info("Admin %s created staff user %s with role %s", current_user.username, new_user.username, role_key)

    return UserProfileOut(
        id=new_user.id,
        username=new_user.username,
        display_name=new_user.display_name,
        email=new_user.email,
        phone=new_user.phone,
        is_active=new_user.is_active,
        role=role_key,
        role_label=ROLE_LABELS.get(role_key, role_key),
        permissions=perms,
    )


@router.put(
    "/{user_id}",
    response_model=UserProfileOut,
    summary="Update staff member profile, role, or active status",
)
async def update_user(
    user_id: uuid.UUID,
    payload: UpdateUserRequest,
    current_user: CurrentUser = Depends(require_permission("users:manage")),
    session: AsyncSession = Depends(get_db),
) -> Any:
    """Updates user information, active status, and assigns a new role if provided."""
    target_user = await session.get(User, user_id)
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff member not found.",
        )

    # Protect self-deactivation
    if payload.is_active is False and target_user.id == current_user.user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot deactivate your own account.",
        )

    if payload.display_name is not None:
        target_user.display_name = payload.display_name.strip()
    if payload.email is not None:
        target_user.email = payload.email.strip() if payload.email.strip() else None
    if payload.phone is not None:
        target_user.phone = payload.phone.strip() if payload.phone.strip() else None
    if payload.is_active is not None:
        target_user.is_active = payload.is_active

    # Update role if provided
    role_key, perms = await _resolve_user_role_and_permissions(
        session, current_user.business_id, target_user
    )

    if payload.role:
        new_role_key = payload.role.strip().upper()
        if new_role_key in ROLE_PERMISSIONS:
            role_key = new_role_key
            perms = payload.custom_permissions or ROLE_PERMISSIONS.get(role_key, [])

            # Update MembershipRole
            m_stmt = select(Membership).where(
                Membership.business_id == current_user.business_id,
                Membership.user_id == target_user.id,
            )
            m_obj = (await session.execute(m_stmt)).scalars().first()
            if m_obj:
                # Find or create role
                r_stmt = select(Role).where(
                    or_(Role.business_id == current_user.business_id, Role.business_id.is_(None)),
                    Role.name == role_key,
                )
                r_obj = (await session.execute(r_stmt)).scalars().first()
                if not r_obj:
                    r_obj = Role(
                        business_id=current_user.business_id,
                        name=role_key,
                        description=ROLE_LABELS.get(role_key, role_key),
                    )
                    session.add(r_obj)
                    await session.flush()

                # Clean existing membership roles
                del_mr = select(MembershipRole).where(MembershipRole.membership_id == m_obj.id)
                existing_mrs = list((await session.execute(del_mr)).scalars().all())
                for emr in existing_mrs:
                    await session.delete(emr)

                session.add(MembershipRole(membership_id=m_obj.id, role_id=r_obj.id))

    await session.commit()
    await session.refresh(target_user)

    return UserProfileOut(
        id=target_user.id,
        username=target_user.username,
        display_name=target_user.display_name,
        email=target_user.email,
        phone=target_user.phone,
        is_active=target_user.is_active,
        role=role_key,
        role_label=ROLE_LABELS.get(role_key, role_key),
        permissions=perms,
    )


@router.put(
    "/{user_id}/password",
    response_model=dict[str, str],
    summary="Reset staff user password",
)
async def reset_user_password(
    user_id: uuid.UUID,
    payload: ChangeUserPasswordRequest,
    current_user: CurrentUser = Depends(require_permission("users:manage")),
    session: AsyncSession = Depends(get_db),
) -> Any:
    """Updates password for a staff member."""
    target_user = await session.get(User, user_id)
    if not target_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Staff member not found.")

    target_user.password_hash = ph.hash(payload.new_password)
    await session.commit()
    return {"message": f"Password for {target_user.username} successfully updated."}


@router.delete(
    "/{user_id}",
    response_model=dict[str, str],
    summary="Deactivate staff user account",
)
async def deactivate_user(
    user_id: uuid.UUID,
    current_user: CurrentUser = Depends(require_permission("users:manage")),
    session: AsyncSession = Depends(get_db),
) -> Any:
    """Deactivates a staff user account preventing future logins."""
    if user_id == current_user.user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot deactivate your own account.",
        )

    target_user = await session.get(User, user_id)
    if not target_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Staff member not found.")

    target_user.is_active = False
    await session.commit()
    return {"message": f"Staff user {target_user.username} has been deactivated."}
