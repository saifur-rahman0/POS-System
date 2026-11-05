"""Comprehensive unit and integration tests for Track 10: Expense and Financial Management."""

import uuid
from collections.abc import AsyncGenerator
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session_maker
from app.modules.business.models import Branch, Business
from app.modules.identity.models import User
from app.modules.purchasing.models import Purchase, Supplier
from app.shared.auth import create_access_token


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    session_factory = get_session_maker()
    async with session_factory() as session:
        yield session


@pytest.fixture
async def test_biz(db_session: AsyncSession) -> Business:
    biz = Business(
        id=uuid.uuid4(),
        name=f"Finance Test Corp {uuid.uuid4().hex[:6]}",
        timezone="Asia/Dhaka",
        currency="BDT",
    )
    db_session.add(biz)
    await db_session.flush()

    branch = Branch(
        id=uuid.uuid4(),
        business_id=biz.id,
        name="Gulshan Branch",
        code="GLS",
        is_active=True,
    )
    db_session.add(branch)
    await db_session.commit()
    await db_session.refresh(biz)
    return biz


@pytest.fixture
async def test_branch(db_session: AsyncSession, test_biz: Business) -> Branch:
    stmt = select(Branch).where(Branch.business_id == test_biz.id)
    res = await db_session.execute(stmt)
    return res.scalars().first()  # type: ignore


@pytest.fixture
async def test_user(db_session: AsyncSession) -> User:
    user = User(
        id=uuid.uuid4(),
        username=f"fin_mgr_{uuid.uuid4().hex[:8]}",
        password_hash="test_pw_hash",
        display_name="Finance Manager",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
def auth_headers(test_biz: Business, test_user: User) -> dict[str, str]:
    token = create_access_token(
        user_id=test_user.id,
        business_id=test_biz.id,
        username=test_user.username,
        permissions={"*"},
    )
    return {"Authorization": f"Bearer {token}"}


# ============================================================================
# 1. Expense Categories & Budgets
# ============================================================================
@pytest.mark.asyncio
async def test_expense_category_lifecycle(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_biz: Business,
) -> None:
    # 1. Create category
    cat_payload = {
        "name": "Office Utilities & Electricity",
        "code": "UTIL-ELEC",
        "description": "Monthly electricity bills",
        "monthly_budget": 15000.0,
        "is_active": True,
    }
    resp = await client.post("/api/v1/expenses/categories", json=cat_payload, headers=auth_headers)
    assert resp.status_code == 201
    cat_data = resp.json()
    assert cat_data["code"] == "UTIL-ELEC"
    assert Decimal(str(cat_data["monthly_budget"])) == Decimal("15000.0000")
    cat_id = cat_data["id"]

    # 2. Duplicate code rejected
    dup_resp = await client.post("/api/v1/expenses/categories", json=cat_payload, headers=auth_headers)
    assert dup_resp.status_code == 400

    # 3. List categories
    list_resp = await client.get("/api/v1/expenses/categories", headers=auth_headers)
    assert list_resp.status_code == 200
    items = list_resp.json()
    assert any(c["id"] == cat_id for c in items)

    # 4. Update category
    upd_payload = {"monthly_budget": 18000.0, "description": "Updated bill budget"}
    upd_resp = await client.put(f"/api/v1/expenses/categories/{cat_id}", json=upd_payload, headers=auth_headers)
    assert upd_resp.status_code == 200
    assert Decimal(str(upd_resp.json()["monthly_budget"])) == Decimal("18000.0000")


# ============================================================================
# 2. Financial Accounts & Transfers
# ============================================================================
@pytest.mark.asyncio
async def test_financial_accounts_and_transfers(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_branch: Branch,
) -> None:
    # 1. Create Store Safe Account (opening ৳ 50,000)
    safe_payload = {
        "branch_id": str(test_branch.id),
        "account_name": "Main Vault Safe",
        "account_type": "SAFE",
        "opening_balance": 50000.0,
    }
    safe_res = await client.post("/api/v1/financial-accounts", json=safe_payload, headers=auth_headers)
    assert safe_res.status_code == 201
    safe_data = safe_res.json()
    safe_id = safe_data["id"]
    assert Decimal(str(safe_data["current_balance"])) == Decimal("50000.0000")

    # 2. Create Commercial Bank Account (opening ৳ 100,000)
    bank_payload = {
        "account_name": "City Bank Corporate Current",
        "account_type": "BANK",
        "account_number": "1102938475",
        "bank_name": "City Bank PLC",
        "opening_balance": 100000.0,
    }
    bank_res = await client.post("/api/v1/financial-accounts", json=bank_payload, headers=auth_headers)
    assert bank_res.status_code == 201
    bank_data = bank_res.json()
    bank_id = bank_data["id"]

    # 3. Inter-account transfer: Safe to Bank ৳ 20,000
    transfer_payload = {
        "from_account_id": safe_id,
        "to_account_id": bank_id,
        "amount": 20000.0,
        "note": "Vault excess cash deposit to City Bank",
    }
    trf_res = await client.post("/api/v1/financial-accounts/transfers", json=transfer_payload, headers=auth_headers)
    assert trf_res.status_code == 201
    trf_data = trf_res.json()
    assert trf_data["reference_no"].startswith("TRF-")
    assert Decimal(str(trf_data["amount"])) == Decimal("20000.0000")

    # Verify updated balances
    accs_res = await client.get("/api/v1/financial-accounts", headers=auth_headers)
    assert accs_res.status_code == 200
    acc_map = {a["id"]: Decimal(str(a["current_balance"])) for a in accs_res.json()}
    assert acc_map[safe_id] == Decimal("30000.0000")
    assert acc_map[bank_id] == Decimal("120000.0000")

    # 4. Transfer exceeding balance fails with 400
    fail_transfer = {
        "from_account_id": safe_id,
        "to_account_id": bank_id,
        "amount": 999999.0,
        "note": "Overdraft attempt",
    }
    fail_res = await client.post("/api/v1/financial-accounts/transfers", json=fail_transfer, headers=auth_headers)
    assert fail_res.status_code == 400


# ============================================================================
# 3. Operating Expenses & Approval Workflow (> ৳ 5,000 Threshold)
# ============================================================================
@pytest.mark.asyncio
async def test_expense_under_threshold_auto_approves(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_branch: Branch,
) -> None:
    # 1. Setup Petty Cash Account (৳ 10,000)
    acc_res = await client.post(
        "/api/v1/financial-accounts",
        json={
            "branch_id": str(test_branch.id),
            "account_name": "Counter Petty Cash",
            "account_type": "PETTY_CASH",
            "opening_balance": 10000.0,
        },
        headers=auth_headers,
    )
    acc_id = acc_res.json()["id"]

    # 2. Record Expense ৳ 1,500 (< 5,000) -> immediately APPROVED
    exp_payload = {
        "branch_id": str(test_branch.id),
        "category": "Office Snacks & Tea",
        "amount": 1500.0,
        "payment_account_id": acc_id,
        "payment_method": "CASH",
        "payee": "Local Tea Stall",
        "tax_deductible": True,
        "note": "Weekly staff refreshments",
    }
    res = await client.post("/api/v1/expenses", json=exp_payload, headers=auth_headers)
    assert res.status_code == 201
    data = res.json()
    assert data["approval_status"] == "APPROVED"
    assert data["voucher_no"].startswith("EXP-")
    assert data["approved_by"] is not None

    # Verify petty cash balance decremented to ৳ 8,500
    acc_check = await client.get("/api/v1/financial-accounts", headers=auth_headers)
    petty_acc = next(a for a in acc_check.json() if a["id"] == acc_id)
    assert Decimal(str(petty_acc["current_balance"])) == Decimal("8500.0000")


@pytest.mark.asyncio
async def test_expense_over_threshold_requires_manager_approval(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_branch: Branch,
) -> None:
    # 1. Setup Bank Account (৳ 200,000)
    bank_res = await client.post(
        "/api/v1/financial-accounts",
        json={
            "account_name": "Operations Checking",
            "account_type": "BANK",
            "opening_balance": 200000.0,
        },
        headers=auth_headers,
    )
    bank_id = bank_res.json()["id"]

    # 2. Record High-Value Expense ৳ 35,000 (> 5,000 threshold)
    exp_payload = {
        "branch_id": str(test_branch.id),
        "category": "Store Monthly Rent",
        "amount": 35000.0,
        "payment_account_id": bank_id,
        "payment_method": "BANK",
        "payee": "Commercial Building Landlord",
        "tax_deductible": True,
        "note": "Rent for Nov 2026",
    }
    exp_res = await client.post("/api/v1/expenses", json=exp_payload, headers=auth_headers)
    assert exp_res.status_code == 201
    exp_data = exp_res.json()
    exp_id = exp_data["id"]
    assert exp_data["approval_status"] == "PENDING_APPROVAL"
    assert exp_data["approved_by"] is None

    # Financial account is NOT yet decremented while pending
    bank_check1 = await client.get("/api/v1/financial-accounts", headers=auth_headers)
    acc1 = next(a for a in bank_check1.json() if a["id"] == bank_id)
    assert Decimal(str(acc1["current_balance"])) == Decimal("200000.0000")

    # 3. Manager approves expense voucher
    appr_res = await client.post(
        f"/api/v1/expenses/{exp_id}/approve",
        json={"action": "APPROVED", "note": "Verified against tenancy agreement"},
        headers=auth_headers,
    )
    assert appr_res.status_code == 200
    appr_data = appr_res.json()
    assert appr_data["approval_status"] == "APPROVED"
    assert appr_data["approved_by"] is not None

    # Now account balance is decremented to ৳ 165,000
    bank_check2 = await client.get("/api/v1/financial-accounts", headers=auth_headers)
    acc2 = next(a for a in bank_check2.json() if a["id"] == bank_id)
    assert Decimal(str(acc2["current_balance"])) == Decimal("165000.0000")


# ============================================================================
# 4. Recurring Expenses & Automation
# ============================================================================
@pytest.mark.asyncio
async def test_recurring_expense_schedule_and_auto_post(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_branch: Branch,
) -> None:
    # 1. Create Category
    cat_res = await client.post(
        "/api/v1/expenses/categories",
        json={"name": "Internet & Software", "code": "INT-SOFT", "monthly_budget": 5000.0},
        headers=auth_headers,
    )
    cat_id = cat_res.json()["id"]

    # 2. Schedule Recurring Expense
    today = date.today()
    rec_payload = {
        "branch_id": str(test_branch.id),
        "category_id": cat_id,
        "title": "High-Speed Fiber Internet",
        "amount": 2500.0,
        "frequency": "MONTHLY",
        "next_due_date": today.isoformat(),
        "auto_post": True,
    }
    rec_res = await client.post("/api/v1/expenses/recurring", json=rec_payload, headers=auth_headers)
    assert rec_res.status_code == 201
    rec_id = rec_res.json()["id"]

    # 3. Process due recurring expenses
    proc_res = await client.post(
        f"/api/v1/expenses/recurring/process?as_of_date={today.isoformat()}",
        headers=auth_headers,
    )
    assert proc_res.status_code == 200
    vouchers = proc_res.json()
    assert len(vouchers) >= 1
    assert any("Auto-generated" in v["note"] for v in vouchers)

    # 4. Verify schedule next_due_date moved forward 1 month
    recs_res = await client.get("/api/v1/expenses/recurring", headers=auth_headers)
    assert recs_res.status_code == 200
    rec_item = next(r for r in recs_res.json() if r["id"] == rec_id)
    assert rec_item["last_generated_at"] is not None
    assert rec_item["next_due_date"] > today.isoformat()


# ============================================================================
# 5. Financial Reports (Cash Flow & AP Aging)
# ============================================================================
@pytest.mark.asyncio
async def test_cash_flow_and_ap_aging_reports(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_biz: Business,
    test_branch: Branch,
    test_user: User,
    db_session: AsyncSession,
) -> None:
    # 1. Add Supplier and Overdue Purchase for AP Aging
    supp = Supplier(
        business_id=test_biz.id,
        name="Apex Distribution Ltd",
        code=f"SUP-{uuid.uuid4().hex[:6].upper()}",
        contact_person="Rahman",
        phone="01700000000",
    )
    db_session.add(supp)
    await db_session.flush()

    past_date = datetime.now(UTC) - timedelta(days=45)
    po = Purchase(
        business_id=test_biz.id,
        branch_id=test_branch.id,
        supplier_id=supp.id,
        reference_no=f"PO-{uuid.uuid4().hex[:6].upper()}",
        status="RECEIVED",
        subtotal=Decimal("50000.0000"),
        discount=Decimal("0.0000"),
        total=Decimal("50000.0000"),
        paid_total=Decimal("20000.0000"),  # ৳ 30,000 remains unpaid (31-60 days bucket)
        created_by=test_user.id,
        created_at=past_date,
    )
    db_session.add(po)
    await db_session.commit()

    # 2. Check AP Aging Report
    ap_res = await client.get("/api/v1/financial-accounts/reports/ap-aging", headers=auth_headers)
    assert ap_res.status_code == 200
    ap_data = ap_res.json()
    assert Decimal(str(ap_data["total_payable"])) >= Decimal("30000.0000")
    b31_60 = next((b for b in ap_data["buckets"] if b["bucket_name"] == "31-60 Days"), None)
    assert b31_60 is not None
    assert Decimal(str(b31_60["total_amount"])) >= Decimal("30000.0000")

    # 3. Check Cash Flow Report
    today = date.today()
    start_date = (today - timedelta(days=30)).isoformat()
    end_date = today.isoformat()
    cf_res = await client.get(
        f"/api/v1/financial-accounts/reports/cash-flow?start_date={start_date}&end_date={end_date}",
        headers=auth_headers,
    )
    assert cf_res.status_code == 200
    cf_data = cf_res.json()
    assert "total_cash_in" in cf_data
    assert "total_cash_out" in cf_data
    assert "net_cash_flow" in cf_data
