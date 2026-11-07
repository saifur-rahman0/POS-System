"""Comprehensive Demo Data Seeder for Tracks 1–13.

Ensures all modules (Catalog, Shifts, Sales, Purchasing, Expenses, Financial Accounts,
Inventory Batches, Damaged Stock, Reservations, Price Lists, Promotions, Customer Groups,
Loyalty, Tiers, Gift Cards) have realistic demonstration data.
"""

import asyncio
import os
import sys
import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

# Ensure backend directory is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from sqlalchemy import select, text
from app.database import get_session_maker
from app.shared.auth import DEV_BUSINESS_ID, DEV_USER_ID

# Domain models
from app.modules.business.models import Branch, Business
from app.modules.catalog.models import Brand, Category, Product, ProductVariant
from app.modules.sales.models import Customer
from app.modules.expenses.models import (
    AccountTransfer,
    Expense,
    ExpenseCategory,
    FinancialAccount,
    RecurringExpense,
)
from app.modules.inventory.models import (
    DamagedStockRecord,
    InventoryBatch,
    StockBalance,
    StockMovement,
    StockReservation,
    StockTransfer,
    StockTransferItem,
)
from app.modules.pricing.models import (
    CustomerGroup,
    CustomerGroupMember,
    PriceList,
    PriceListItem,
    Promotion,
)
from app.modules.crm.models import (
    CreditNote,
    GiftCard,
    GiftCardTransaction,
    LoyaltySettings,
    MembershipTier,
)
from app.modules.crm.gift_card_service import GiftCardService


DEV_BRANCH_ID = uuid.UUID("00000000-0000-0000-0000-000000000002")
BRANCH_DHAN_ID = uuid.UUID("00000000-0000-0000-0000-000000000003")
BRANCH_UTTR_ID = uuid.UUID("00000000-0000-0000-0000-000000000004")


async def seed_all() -> None:
    session_maker = get_session_maker()
    now_utc = datetime.now(UTC).replace(tzinfo=None)

    async with session_maker() as session:
        print("[1/8] Verifying and updating Branch types...")
        # 1. Update branches if branch_type is null or missing
        await session.execute(
            text(
                "UPDATE branches SET branch_type = 'RETAIL_STORE' "
                "WHERE branch_type IS NULL OR branch_type = ''"
            )
        )
        # Ensure Dhanmondi and Uttara branches exist
        dhan_res = await session.execute(select(Branch).where(Branch.id == BRANCH_DHAN_ID))
        if not dhan_res.scalars().first():
            session.add(
                Branch(
                    id=BRANCH_DHAN_ID,
                    business_id=DEV_BUSINESS_ID,
                    name="Dhanmondi Branch",
                    code="DHAN",
                    address="Plot 24, Satmasjid Road, Dhanmondi, Dhaka",
                    phone="+880 1711 000002",
                    branch_type="RETAIL_STORE",
                    is_active=True,
                )
            )
        uttr_res = await session.execute(select(Branch).where(Branch.id == BRANCH_UTTR_ID))
        if not uttr_res.scalars().first():
            session.add(
                Branch(
                    id=BRANCH_UTTR_ID,
                    business_id=DEV_BUSINESS_ID,
                    name="Uttara Central Warehouse",
                    code="UTTR",
                    address="Sector 3, Jashimuddin Avenue, Uttara, Dhaka",
                    phone="+880 1711 000003",
                    branch_type="CENTRAL_WAREHOUSE",
                    is_active=True,
                )
            )
        await session.flush()

        print("[2/8] Seeding Financial Accounts and Transfers (Track 10)...")
        # 2. Financial Accounts
        acct_safe = await session.execute(
            select(FinancialAccount).where(
                FinancialAccount.business_id == DEV_BUSINESS_ID,
                FinancialAccount.account_name == "Main Store Vault (Safe)",
            )
        )
        safe_entity = acct_safe.scalars().first()
        if not safe_entity:
            safe_entity = FinancialAccount(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                branch_id=DEV_BRANCH_ID,
                account_name="Main Store Vault (Safe)",
                account_type="SAFE",
                opening_balance=Decimal("150000.0000"),
                current_balance=Decimal("185000.0000"),
                is_active=True,
            )
            drawer_entity = FinancialAccount(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                branch_id=DEV_BRANCH_ID,
                account_name="POS Terminal Register Drawer",
                account_type="CASH_DRAWER",
                opening_balance=Decimal("10000.0000"),
                current_balance=Decimal("28450.0000"),
                is_active=True,
            )
            bank_entity = FinancialAccount(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                branch_id=DEV_BRANCH_ID,
                account_name="City Bank Corporate A/C",
                account_type="BANK",
                bank_name="City Bank Ltd",
                account_number="110-234-998877",
                opening_balance=Decimal("350000.0000"),
                current_balance=Decimal("495000.0000"),
                is_active=True,
            )
            bkash_entity = FinancialAccount(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                branch_id=DEV_BRANCH_ID,
                account_name="bKash Merchant Wallet",
                account_type="MOBILE_WALLET",
                bank_name="bKash Limited",
                account_number="01711000001",
                opening_balance=Decimal("20000.0000"),
                current_balance=Decimal("42600.0000"),
                is_active=True,
            )
            petty_entity = FinancialAccount(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                branch_id=DEV_BRANCH_ID,
                account_name="Petty Cash Box",
                account_type="PETTY_CASH",
                opening_balance=Decimal("5000.0000"),
                current_balance=Decimal("8350.0000"),
                is_active=True,
            )
            session.add_all([safe_entity, drawer_entity, bank_entity, bkash_entity, petty_entity])
            await session.flush()

            # Seed Account Transfers
            trf1 = AccountTransfer(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                from_account_id=safe_entity.id,
                to_account_id=drawer_entity.id,
                amount=Decimal("15000.0000"),
                reference_no="TRF-20261105-001",
                note="Morning register float replenishment from safe",
                transfer_date=now_utc - timedelta(days=2),
                created_by=DEV_USER_ID,
            )
            trf2 = AccountTransfer(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                from_account_id=drawer_entity.id,
                to_account_id=bank_entity.id,
                amount=Decimal("40000.0000"),
                reference_no="TRF-20261105-002",
                note="Daily closing cash sales bank deposit",
                transfer_date=now_utc - timedelta(days=1),
                created_by=DEV_USER_ID,
            )
            trf3 = AccountTransfer(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                from_account_id=bank_entity.id,
                to_account_id=bkash_entity.id,
                amount=Decimal("20000.0000"),
                reference_no="TRF-20261106-003",
                note="bKash merchant float top-up via corporate online banking",
                transfer_date=now_utc - timedelta(hours=6),
                created_by=DEV_USER_ID,
            )
            session.add_all([trf1, trf2, trf3])
            await session.flush()
        else:
            drawer_res = await session.execute(
                select(FinancialAccount).where(
                    FinancialAccount.business_id == DEV_BUSINESS_ID,
                    FinancialAccount.account_type == "CASH_DRAWER",
                )
            )
            drawer_entity = drawer_res.scalars().first() or safe_entity

        print("[3/8] Seeding Expense Categories and Vouchers (Track 10)...")
        # 3. Expense Categories
        cat_rent_res = await session.execute(
            select(ExpenseCategory).where(
                ExpenseCategory.business_id == DEV_BUSINESS_ID,
                ExpenseCategory.code == "RENT",
            )
        )
        cat_rent = cat_rent_res.scalars().first()
        if not cat_rent:
            cat_rent = ExpenseCategory(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                name="Shop Rent & Facilities",
                code="RENT",
                description="Monthly lease, showroom rent, and service charges",
                monthly_budget=Decimal("50000.0000"),
                is_active=True,
            )
            cat_util = ExpenseCategory(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                name="Electricity & Utilities",
                code="UTIL",
                description="DESCO power, generator diesel, and water bills",
                monthly_budget=Decimal("12000.0000"),
                is_active=True,
            )
            cat_staff = ExpenseCategory(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                name="Staff Entertainment & Tea",
                code="TEA",
                description="Daily staff tea, snacks, and water dispenser bottles",
                monthly_budget=Decimal("5000.0000"),
                is_active=True,
            )
            cat_maint = ExpenseCategory(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                name="Maintenance & Repairs",
                code="MAINT",
                description="AC servicing, electrical fittings, and POS hardware repairs",
                monthly_budget=Decimal("8000.0000"),
                is_active=True,
            )
            cat_mktg = ExpenseCategory(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                name="Marketing & Promotion",
                code="MKTG",
                description="Flyers, banners, SMS campaigns, and digital ads",
                monthly_budget=Decimal("15000.0000"),
                is_active=True,
            )
            session.add_all([cat_rent, cat_util, cat_staff, cat_maint, cat_mktg])
            await session.flush()

            # Seed Expenses
            exp1 = Expense(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                branch_id=DEV_BRANCH_ID,
                voucher_no="EXP-20261101-0001",
                category_id=cat_rent.id,
                category=cat_rent.name,
                payment_account_id=safe_entity.id,
                payment_method="BANK",
                payee="Gulshan Plaza Holdings Ltd.",
                receipt_reference="RENT-NOV-2026",
                amount=Decimal("45000.0000"),
                tax_deductible=True,
                note="Advance showroom rent payment for November 2026",
                approval_status="APPROVED",
                approved_by=DEV_USER_ID,
                approved_at=now_utc - timedelta(days=5),
                created_by=DEV_USER_ID,
                created_at=now_utc - timedelta(days=5),
            )
            exp2 = Expense(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                branch_id=DEV_BRANCH_ID,
                voucher_no="EXP-20261102-0002",
                category_id=cat_util.id,
                category=cat_util.name,
                payment_account_id=drawer_entity.id,
                payment_method="CASH",
                payee="DESCO Utility Billing Counter",
                receipt_reference="BILL-OCT-9988",
                amount=Decimal("6850.0000"),
                tax_deductible=False,
                note="Commercial electricity bill payment for October meter reading",
                approval_status="APPROVED",
                approved_by=DEV_USER_ID,
                approved_at=now_utc - timedelta(days=4),
                created_by=DEV_USER_ID,
                created_at=now_utc - timedelta(days=4),
            )
            exp3 = Expense(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                branch_id=DEV_BRANCH_ID,
                voucher_no="EXP-20261103-0003",
                category_id=cat_staff.id,
                category=cat_staff.name,
                payment_account_id=drawer_entity.id,
                payment_method="CASH",
                payee="Bhai Bhai Bakery & Tea Stall",
                receipt_reference=None,
                amount=Decimal("1420.0000"),
                tax_deductible=False,
                note="Weekly staff morning tea, biscuits, and afternoon snacks",
                approval_status="APPROVED",
                approved_by=DEV_USER_ID,
                approved_at=now_utc - timedelta(days=3),
                created_by=DEV_USER_ID,
                created_at=now_utc - timedelta(days=3),
            )
            exp4 = Expense(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                branch_id=DEV_BRANCH_ID,
                voucher_no="EXP-20261105-0004",
                category_id=cat_maint.id,
                category=cat_maint.name,
                payment_account_id=drawer_entity.id,
                payment_method="CASH",
                payee="Cool Air Solution Technicians",
                receipt_reference="SVC-776",
                amount=Decimal("3800.0000"),
                tax_deductible=False,
                note="General gas refill and servicing of showroom central split AC",
                approval_status="APPROVED",
                approved_by=DEV_USER_ID,
                approved_at=now_utc - timedelta(days=1),
                created_by=DEV_USER_ID,
                created_at=now_utc - timedelta(days=1),
            )
            exp5 = Expense(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                branch_id=DEV_BRANCH_ID,
                voucher_no="EXP-20261107-0005",
                category_id=cat_mktg.id,
                category=cat_mktg.name,
                payment_account_id=safe_entity.id,
                payment_method="BKASH",
                payee="Creative Digital Media House",
                receipt_reference="QUO-MKT-09",
                amount=Decimal("7500.0000"),
                tax_deductible=True,
                note="Pre-Eid promotional print leaflets and Facebook social campaign",
                approval_status="PENDING_APPROVAL",
                approved_by=None,
                approved_at=None,
                created_by=DEV_USER_ID,
                created_at=now_utc - timedelta(hours=3),
            )
            session.add_all([exp1, exp2, exp3, exp4, exp5])

            # Recurring commitments
            rec1 = RecurringExpense(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                branch_id=DEV_BRANCH_ID,
                category_id=cat_rent.id,
                payment_account_id=safe_entity.id,
                title="Monthly Commercial Showroom Rent",
                amount=Decimal("45000.0000"),
                frequency="MONTHLY",
                next_due_date=date.today() + timedelta(days=24),
                last_generated_at=now_utc - timedelta(days=6),
                auto_post=False,
                is_active=True,
            )
            rec2 = RecurringExpense(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                branch_id=DEV_BRANCH_ID,
                category_id=cat_util.id,
                payment_account_id=drawer_entity.id,
                title="Fiber Optic High-Speed Internet Bill",
                amount=Decimal("2500.0000"),
                frequency="MONTHLY",
                next_due_date=date.today() + timedelta(days=12),
                last_generated_at=now_utc - timedelta(days=18),
                auto_post=True,
                is_active=True,
            )
            session.add_all([rec1, rec2])
            await session.flush()

        print("[4/8] Seeding Batches, Damaged Stock, and Stock Reservations (Track 11)...")
        # 4. Inventory Batches
        var_stmt = select(ProductVariant).where(ProductVariant.business_id == DEV_BUSINESS_ID)
        variants = (await session.execute(var_stmt)).scalars().all()

        if variants:
            v_first = variants[0]
            v_second = variants[1] if len(variants) > 1 else variants[0]

            batch_res = await session.execute(
                select(InventoryBatch).where(
                    InventoryBatch.business_id == DEV_BUSINESS_ID,
                    InventoryBatch.product_variant_id == v_first.id,
                )
            )
            b1 = batch_res.scalars().first()
            if not b1:
                b1 = InventoryBatch(
                    id=uuid.uuid4(),
                    business_id=DEV_BUSINESS_ID,
                    branch_id=DEV_BRANCH_ID,
                    product_variant_id=v_first.id,
                    batch_number="BAT-2026-NOV-001",
                    manufacturing_date=date.today() - timedelta(days=30),
                    expiry_date=date.today() + timedelta(days=180),
                    quantity_received=Decimal("150.0000"),
                    quantity_on_hand=Decimal("115.0000"),
                    cost_price=v_first.cost_price,
                    is_active=True,
                )
                b2 = InventoryBatch(
                    id=uuid.uuid4(),
                    business_id=DEV_BUSINESS_ID,
                    branch_id=DEV_BRANCH_ID,
                    product_variant_id=v_second.id,
                    batch_number="BAT-2026-OCT-092",
                    manufacturing_date=date.today() - timedelta(days=60),
                    expiry_date=date.today() + timedelta(days=12),  # Expiring soon
                    quantity_received=Decimal("50.0000"),
                    quantity_on_hand=Decimal("24.0000"),
                    cost_price=v_second.cost_price,
                    is_active=True,
                )
                b3 = InventoryBatch(
                    id=uuid.uuid4(),
                    business_id=DEV_BUSINESS_ID,
                    branch_id=DEV_BRANCH_ID,
                    product_variant_id=v_first.id,
                    batch_number="BAT-2026-OLD-011",
                    manufacturing_date=date.today() - timedelta(days=120),
                    expiry_date=date.today() - timedelta(days=5),  # Expired
                    quantity_received=Decimal("20.0000"),
                    quantity_on_hand=Decimal("6.0000"),
                    cost_price=v_first.cost_price,
                    is_active=True,
                )
                session.add_all([b1, b2, b3])
                await session.flush()

                # Damaged stock records
                dam1 = DamagedStockRecord(
                    id=uuid.uuid4(),
                    business_id=DEV_BUSINESS_ID,
                    branch_id=DEV_BRANCH_ID,
                    product_variant_id=v_first.id,
                    batch_id=b3.id,
                    voucher_no="DAM-20261105-001",
                    quantity=Decimal("4.0000"),
                    unit_cost=v_first.cost_price,
                    total_loss=v_first.cost_price * Decimal("4.0000"),
                    reason="EXPIRED",
                    disposal_method="DESTROYED",
                    notes="Expired beverage stock disposed of according to standard audit protocol",
                    reported_by=DEV_USER_ID,
                    approved_by=DEV_USER_ID,
                    created_at=now_utc - timedelta(days=2),
                )
                dam2 = DamagedStockRecord(
                    id=uuid.uuid4(),
                    business_id=DEV_BUSINESS_ID,
                    branch_id=DEV_BRANCH_ID,
                    product_variant_id=v_second.id,
                    batch_id=b2.id,
                    voucher_no="DAM-20261106-002",
                    quantity=Decimal("2.0000"),
                    unit_cost=v_second.cost_price,
                    total_loss=v_second.cost_price * Decimal("2.0000"),
                    reason="BROKEN",
                    disposal_method="WRITTEN_OFF",
                    notes="Glass bottle carton dropped during warehouse shelf reorganization",
                    reported_by=DEV_USER_ID,
                    approved_by=DEV_USER_ID,
                    created_at=now_utc - timedelta(days=1),
                )
                session.add_all([dam1, dam2])

                # Stock reservations
                res1 = StockReservation(
                    id=uuid.uuid4(),
                    business_id=DEV_BUSINESS_ID,
                    branch_id=DEV_BRANCH_ID,
                    product_variant_id=v_first.id,
                    quantity=Decimal("10.0000"),
                    reference_type="QUOTATION",
                    reference_id=uuid.uuid4(),
                    status="ACTIVE",
                    reserved_until=now_utc + timedelta(days=3),
                    created_by=DEV_USER_ID,
                )
                session.add(res1)
                await session.flush()

        print("[5/8] Seeding Price Lists, Customer Groups, and Promotions (Track 12)...")
        # 5. Customer Groups and Price Lists
        grp_b2b_res = await session.execute(
            select(CustomerGroup).where(
                CustomerGroup.business_id == DEV_BUSINESS_ID,
                CustomerGroup.name == "Wholesale B2B Clients",
            )
        )
        grp_b2b = grp_b2b_res.scalars().first()
        if not grp_b2b:
            grp_b2b = CustomerGroup(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                name="Wholesale B2B Clients",
                description="Corporate bulk buyers with special discounted tier pricing",
                is_active=True,
            )
            grp_vip = CustomerGroup(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                name="VIP Retail Members",
                description="High-frequency privileged retail customers",
                is_active=True,
            )
            session.add_all([grp_b2b, grp_vip])
            await session.flush()

            # Price list
            plist = PriceList(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                name="Wholesale Special Price List 2026",
                currency="BDT",
                is_default=False,
                is_active=True,
            )
            session.add(plist)
            await session.flush()

            if variants:
                pli = PriceListItem(
                    id=uuid.uuid4(),
                    price_list_id=plist.id,
                    product_variant_id=variants[0].id,
                    min_quantity=Decimal("10.0000"),
                    price=variants[0].selling_price * Decimal("0.85"),  # 15% wholesale discount
                )
                session.add(pli)

            # Promotions
            promo1 = Promotion(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                name="Pre-Eid Festive Offer (10% Off)",
                code="EID2026",
                discount_type="PERCENTAGE",
                discount_value=Decimal("10.0000"),
                min_spend=Decimal("500.0000"),
                max_discount_cap=Decimal("300.0000"),
                usage_limit=500,
                times_used=24,
                valid_from=date.today() - timedelta(days=30),
                valid_until=date.today() + timedelta(days=90),
                is_active=True,
            )
            promo2 = Promotion(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                name="Flat ৳ 50 Off First Purchase",
                code="FLAT50",
                discount_type="FIXED_AMOUNT",
                discount_value=Decimal("50.0000"),
                min_spend=Decimal("300.0000"),
                max_discount_cap=None,
                usage_limit=1000,
                times_used=89,
                valid_from=date.today() - timedelta(days=30),
                valid_until=date.today() + timedelta(days=90),
                is_active=True,
            )
            session.add_all([promo1, promo2])
            await session.flush()

        print("[6/8] Seeding Loyalty Program and Membership Tiers (Track 13)...")
        # 6. Loyalty Settings
        loyalty_res = await session.execute(
            select(LoyaltySettings).where(LoyaltySettings.business_id == DEV_BUSINESS_ID)
        )
        if not loyalty_res.scalars().first():
            loyalty_conf = LoyaltySettings(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                is_enabled=True,
                earn_rate=Decimal("1.0000"),  # 1 point per 100 BDT
                redeem_rate=Decimal("0.5000"),  # 1 point = 0.50 BDT
                min_redeem_points=50,
                points_expiry_days=365,
                max_cart_discount_pct=Decimal("50.00"),
            )
            session.add(loyalty_conf)

            # Membership Tiers
            t_bronze = MembershipTier(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                name="Bronze Club",
                code="BRONZE",
                min_spend=Decimal("0.0000"),
                points_multiplier=Decimal("1.00"),
                discount_pct=Decimal("0.00"),
                perks_description="Standard points accumulation on every retail purchase",
                is_active=True,
            )
            t_silver = MembershipTier(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                name="Silver Privilege",
                code="SILVER",
                min_spend=Decimal("10000.0000"),
                points_multiplier=Decimal("1.25"),
                discount_pct=Decimal("3.00"),
                perks_description="1.25x point earnings + 3% discount on apparel and footwear",
                is_active=True,
            )
            t_gold = MembershipTier(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                name="Gold Elite",
                code="GOLD",
                min_spend=Decimal("35000.0000"),
                points_multiplier=Decimal("1.50"),
                discount_pct=Decimal("5.00"),
                perks_description="1.5x points + 5% flat store discount + priority billing",
                is_active=True,
            )
            t_plat = MembershipTier(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                name="Platinum VIP",
                code="PLATINUM",
                min_spend=Decimal("80000.0000"),
                points_multiplier=Decimal("2.00"),
                discount_pct=Decimal("10.00"),
                perks_description="2x double points + 10% VIP discount + free home delivery",
                is_active=True,
            )
            session.add_all([t_bronze, t_silver, t_gold, t_plat])
            await session.flush()

        print("[7/8] Seeding Gift Cards and Customer Credit Notes (Track 13)...")
        # 7. Gift Cards
        gc_res = await session.execute(
            select(GiftCard).where(GiftCard.business_id == DEV_BUSINESS_ID)
        )
        if not gc_res.scalars().first():
            pin_hash1 = GiftCardService.hash_pin("1234")
            gc1 = GiftCard(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                card_number="GC-8849-2026-1000",
                pin_hash=pin_hash1,
                initial_balance=Decimal("1000.0000"),
                current_balance=Decimal("1000.0000"),
                status="ACTIVE",
                recipient_name="Tanvir Hossain",
                recipient_phone="01711998877",
                expires_at=now_utc + timedelta(days=365),
            )
            pin_hash2 = GiftCardService.hash_pin("4321")
            gc2 = GiftCard(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                card_number="GC-5512-2026-2500",
                pin_hash=pin_hash2,
                initial_balance=Decimal("2500.0000"),
                current_balance=Decimal("1850.0000"),
                status="ACTIVE",
                recipient_name="Farzana Yasmin",
                recipient_phone="01811554433",
                expires_at=now_utc + timedelta(days=365),
            )
            session.add_all([gc1, gc2])
            await session.flush()

        print("[8/8] Updating customer loyalty balances and credit balances...")
        # Update existing customers with loyalty points and store credit
        cust_stmt = select(Customer).where(Customer.business_id == DEV_BUSINESS_ID)
        customers = (await session.execute(cust_stmt)).scalars().all()
        for idx, c in enumerate(customers):
            if c.loyalty_points_balance == 0:
                c.loyalty_points_balance = 150 * (idx + 1)
            if c.store_credit_balance == Decimal("0.0000") and idx == 0:
                c.store_credit_balance = Decimal("1500.0000")
            if not c.rfm_segment:
                c.rfm_segment = "LOYAL" if idx % 2 == 0 else "CHAMPION"

        await session.commit()
        print("=" * 70)
        print("ALL DEMO DATA SUCCESSFULLY SEEDED ACROSS ALL TRACKS 1–13!")
        print("=" * 70)


if __name__ == "__main__":
    asyncio.run(seed_all())
