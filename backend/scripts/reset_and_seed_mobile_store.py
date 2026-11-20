"""Comprehensive Database Reset & Modern Mobile & Accessories Store Seeder.

1. Wipes schema 'public' completely.
2. Executes Alembic migrations to head.
3. Populates:
   - Exactly ONE store: Main Store (Gulshan).
   - Standard roles & staff accounts: Stall Owner (admin), Manager (manager), Cashiers (dev_cashier, cashier_sumon), Stock Keeper (stock_keeper).
   - Modern smartphones & mobile accessories catalog (Apple, Samsung, Xiaomi, Google, OnePlus, Anker, Baseus, Spigen, etc.).
   - Serialized IMEI tracking devices.
   - Main Store inventory stock balances and batches.
   - Financial accounts (Vault, Cash Drawer, Bank, bKash, Nagad).
   - Active register shift with starting cash float.
   - Realistic historical & today's sales with diverse tender methods.
   - Operating expenses, customer groups, loyalty tiers, promotions, and gift cards.
"""

import asyncio
import os
import sys
import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

# Ensure backend directory is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from alembic import command
from alembic.config import Config
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

from app.config import get_settings
from app.database import get_session_maker
from app.modules.business.models import Branch, Business
from app.modules.catalog.models import Brand, Category, ImeiDevice, Product, ProductVariant
from app.modules.crm.gift_card_service import GiftCardService
from app.modules.crm.models import GiftCard, LoyaltySettings, MembershipTier
from app.modules.expenses.models import (
    AccountTransfer,
    Expense,
    ExpenseCategory,
    FinancialAccount,
    RecurringExpense,
)
from app.modules.identity.models import Membership, MembershipRole, Role, User
from app.modules.inventory.models import (
    DamagedStockRecord,
    InventoryBatch,
    StockBalance,
    StockMovement,
    StockReservation,
)
from app.modules.pricing.models import (
    CustomerGroup,
    PriceList,
    PriceListItem,
    Promotion,
)
from app.modules.purchasing.models import Purchase, PurchaseItem, Supplier
from app.modules.sales.models import Customer, PaymentTender, Sale, SaleItem
from app.modules.shifts.models import RegisterShift
from app.shared.auth import DEV_BUSINESS_ID, DEV_USER_ID
from app.shared.roles import ROLE_LABELS, ROLE_PERMISSIONS

# Single Main Store Branch ID
DEV_BRANCH_ID = uuid.UUID("00000000-0000-0000-0000-000000000002")

# Fixed User UUIDs for reproducible demo accounts
USER_ADMIN_ID = uuid.UUID("00000000-0000-0000-0000-000000000003")
USER_MANAGER_ID = uuid.UUID("00000000-0000-0000-0000-000000000004")
USER_STOCK_ID = uuid.UUID("00000000-0000-0000-0000-000000000005")
USER_CASHIER2_ID = uuid.UUID("00000000-0000-0000-0000-000000000010")


async def reset_schema() -> None:
    """Drops and recreates public schema in PostgreSQL."""
    settings = get_settings()
    engine = create_async_engine(settings.get_database_url(), echo=False)
    print("Connecting to PostgreSQL to reset schema 'public'...")
    async with engine.begin() as conn:
        await conn.execute(text("DROP SCHEMA IF EXISTS public CASCADE;"))
        await conn.execute(text("CREATE SCHEMA public;"))
        await conn.execute(text("GRANT ALL ON SCHEMA public TO PUBLIC;"))
    await engine.dispose()
    print("Schema 'public' recreated successfully.")


def run_migrations() -> None:
    """Executes Alembic migrations to head."""
    print("Running Alembic migrations to head...")
    backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    ini_path = os.path.join(backend_dir, "alembic.ini")
    alembic_cfg = Config(ini_path)
    alembic_cfg.set_main_option("script_location", os.path.join(backend_dir, "alembic"))
    command.upgrade(alembic_cfg, "head")
    print("Alembic migrations completed successfully.")


async def seed_mobile_store_data() -> None:
    """Seeds modern mobile & accessories store dataset with single main store."""
    session_maker = get_session_maker()
    now_utc = datetime.now(UTC).replace(tzinfo=None)

    async with session_maker() as session:
        print("[1/10] Seeding Business and single Main Store...")
        # 1. Business
        biz = Business(
            id=DEV_BUSINESS_ID,
            name="Apex Mobile & Gadgets",
            legal_name="Apex Mobile & Tech Retail Ltd.",
            timezone="Asia/Dhaka",
            currency="BDT",
            is_active=True,
            created_at=now_utc - timedelta(days=60),
        )
        session.add(biz)
        await session.flush()

        # 2. Only ONE Main Store Branch
        br_main = Branch(
            id=DEV_BRANCH_ID,
            business_id=DEV_BUSINESS_ID,
            name="Main Store (Gulshan)",
            code="MAIN",
            address="House 12, Road 4, Gulshan-1, Dhaka",
            phone="+880 1711 000001",
            branch_type="RETAIL_STORE",
            is_active=True,
            created_at=now_utc - timedelta(days=60),
        )
        session.add(br_main)
        await session.flush()

        print("[2/10] Seeding Roles, Staff Users & Permissions...")
        # 3. Roles
        roles_map: dict[str, Role] = {}
        for r_name, r_label in ROLE_LABELS.items():
            r_obj = Role(
                business_id=DEV_BUSINESS_ID,
                name=r_name,
                description=r_label,
            )
            session.add(r_obj)
            roles_map[r_name] = r_obj
        await session.flush()

        # 4. User Accounts: Admin (Owner), Manager, Senior Cashier, Junior Cashier, Stock Keeper
        users_meta = [
            {
                "id": USER_ADMIN_ID,
                "username": "admin",
                "display_name": "Stall Owner (Admin)",
                "email": "owner@apexmobile.local",
                "phone": "+880 1711 000101",
                "role": "ADMIN",
            },
            {
                "id": USER_MANAGER_ID,
                "username": "manager",
                "display_name": "Tanvir Ahmed (Store Manager)",
                "email": "manager@apexmobile.local",
                "phone": "+880 1711 000102",
                "role": "MANAGER",
            },
            {
                "id": DEV_USER_ID,
                "username": "dev_cashier",
                "display_name": "Counter Cashier (Senior)",
                "email": "cashier@apexmobile.local",
                "phone": "+880 1711 000103",
                "role": "CASHIER",
            },
            {
                "id": USER_CASHIER2_ID,
                "username": "cashier_sumon",
                "display_name": "Sumon Mahmud (Cashier)",
                "email": "sumon@apexmobile.local",
                "phone": "+880 1711 000104",
                "role": "CASHIER",
            },
            {
                "id": USER_STOCK_ID,
                "username": "stock_keeper",
                "display_name": "Faruk Hossain (Stock Keeper)",
                "email": "stock@apexmobile.local",
                "phone": "+880 1711 000105",
                "role": "STOCK_KEEPER",
            },
        ]

        for u in users_meta:
            u_obj = User(
                id=u["id"],
                username=u["username"],
                display_name=u["display_name"],
                email=u["email"],
                phone=u["phone"],
                password_hash="dev_dummy_hash_not_for_prod",
                is_active=True,
                created_at=now_utc - timedelta(days=45),
            )
            session.add(u_obj)
            await session.flush()

            m_obj = Membership(
                business_id=DEV_BUSINESS_ID,
                user_id=u_obj.id,
                status="ACTIVE",
                created_at=now_utc - timedelta(days=45),
            )
            session.add(m_obj)
            await session.flush()

            r_obj = roles_map.get(u["role"])
            if r_obj:
                session.add(MembershipRole(membership_id=m_obj.id, role_id=r_obj.id))

        await session.flush()

        print("[3/10] Seeding Mobile & Accessories Categories and Brands...")
        # 5. Categories
        cat_phones = Category(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Smartphones")
        cat_chargers = Category(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Fast Chargers & Cables")
        cat_audio = Category(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Audio & TWS Earbuds")
        cat_power = Category(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Power Banks & MagSafe")
        cat_protection = Category(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Cases & Protection")
        cat_mounts = Category(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Stands & Mounts")
        cat_wearables = Category(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Smartwatches & Wearables")
        cat_services = Category(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Repair & Services")

        session.add_all([
            cat_phones,
            cat_chargers,
            cat_audio,
            cat_power,
            cat_protection,
            cat_mounts,
            cat_wearables,
            cat_services,
        ])
        await session.flush()

        # 6. Brands
        b_apple = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Apple")
        b_samsung = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Samsung")
        b_xiaomi = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Xiaomi")
        b_google = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Google")
        b_oneplus = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="OnePlus")
        b_anker = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Anker")
        b_baseus = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Baseus")
        b_spigen = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Spigen")
        b_sony = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Sony")
        b_joyroom = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Joyroom")
        b_remax = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Remax")

        session.add_all([
            b_apple,
            b_samsung,
            b_xiaomi,
            b_google,
            b_oneplus,
            b_anker,
            b_baseus,
            b_spigen,
            b_sony,
            b_joyroom,
            b_remax,
        ])
        await session.flush()

        print("[4/10] Seeding Authorized Suppliers and Customer Accounts...")
        # 7. Suppliers
        sup_excel = Supplier(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Excel Technologies Ltd. (Apple Distributor)",
            contact_person="Rashedul Haque",
            phone="+880 1819 112233",
            email="apple.dist@excelbd.com",
            address="BCS Computer City, IDB Bhaban, Dhaka",
        )
        sup_smart = Supplier(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Smart Technologies BD Ltd. (Samsung & Anker)",
            contact_person="Zubair Ahmed",
            phone="+880 1856 789012",
            email="smart.tech@smartbd.com",
            address="Jahangir Tower, Karwan Bazar, Dhaka",
        )
        sup_baseus = Supplier(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Baseus Bangladesh Official Store",
            contact_person="Mahfuzur Rahman",
            phone="+880 1712 345678",
            email="supply@baseus.com.bd",
            address="Jamuna Future Park, Level 4, Dhaka",
        )
        sup_gg = Supplier(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Gadget & Gear Wholesale Division",
            contact_person="Kamrul Hasan",
            phone="+880 1911 223344",
            email="b2b@gadgetandgear.com",
            address="Gulshan Pink City, Dhaka",
        )
        session.add_all([sup_excel, sup_smart, sup_baseus, sup_gg])
        await session.flush()

        # 8. Customers
        c_shakil = Customer(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Md. Shakil Khan (Tech Enthusiast)",
            phone="01711122233",
            email="shakil.khan@gmail.com",
            address="Gulshan-1, Dhaka",
            credit_limit=Decimal("50000.0000"),
            loyalty_points_balance=450,
            store_credit_balance=Decimal("2500.0000"),
            rfm_segment="CHAMPION",
            is_active=True,
        )
        c_farhana = Customer(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Farhana Yasmin (Corporate Buyer)",
            phone="01811223344",
            email="farhana.y@gmail.com",
            address="Banani DOHS, Dhaka",
            credit_limit=Decimal("100000.0000"),
            loyalty_points_balance=850,
            store_credit_balance=Decimal("0.0000"),
            rfm_segment="LOYAL",
            is_active=True,
        )
        c_tariqul = Customer(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Tariqul Islam",
            phone="01911334455",
            email="tariqul.islam@yahoo.com",
            address="Dhanmondi 8/A, Dhaka",
            credit_limit=Decimal("20000.0000"),
            loyalty_points_balance=120,
            store_credit_balance=Decimal("0.0000"),
            rfm_segment="POTENTIAL",
            is_active=True,
        )
        c_nasrin = Customer(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Nasrin Akter",
            phone="01611445566",
            email="nasrin.akter@hotmail.com",
            address="Uttara Sector 7, Dhaka",
            credit_limit=Decimal("25000.0000"),
            loyalty_points_balance=280,
            store_credit_balance=Decimal("500.0000"),
            rfm_segment="LOYAL",
            is_active=True,
        )
        c_arif = Customer(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Arifur Rahman",
            phone="01511556677",
            email="arif.rahman@outlook.com",
            address="Mirpur-10, Dhaka",
            credit_limit=Decimal("15000.0000"),
            loyalty_points_balance=90,
            store_credit_balance=Decimal("0.0000"),
            rfm_segment="AT_RISK",
            is_active=True,
        )
        session.add_all([c_shakil, c_farhana, c_tariqul, c_nasrin, c_arif])
        await session.flush()

        print("[5/10] Seeding Modern Smartphones & Mobile Accessories Products...")

        # -------------------------------------------------------------
        # Helper to quickly create product + variants + stock + movement
        # -------------------------------------------------------------
        all_variants: list[ProductVariant] = []
        all_imeis: list[ImeiDevice] = []
        stock_balances: list[StockBalance] = []
        stock_movements: list[StockMovement] = []

        def add_item(
            product_obj: Product,
            variant_specs: list[dict],
        ):
            session.add(product_obj)
            for spec in variant_specs:
                v = ProductVariant(
                    id=uuid.uuid4(),
                    business_id=DEV_BUSINESS_ID,
                    product_id=product_obj.id,
                    name=spec["name"],
                    barcode=spec["barcode"],
                    cost_price=spec["cost"],
                    selling_price=spec["price"],
                    track_stock=spec.get("track_stock", True),
                    is_active=True,
                )
                all_variants.append(v)

                qty = spec.get("stock", Decimal("10.0000"))
                if v.track_stock:
                    sb = StockBalance(
                        business_id=DEV_BUSINESS_ID,
                        branch_id=DEV_BRANCH_ID,
                        product_variant_id=v.id,
                        quantity_on_hand=qty,
                    )
                    stock_balances.append(sb)

                    if qty > 0:
                        sm = StockMovement(
                            id=uuid.uuid4(),
                            business_id=DEV_BUSINESS_ID,
                            branch_id=DEV_BRANCH_ID,
                            product_variant_id=v.id,
                            movement_type="OPENING_BALANCE",
                            quantity_delta=qty,
                            unit_cost=spec["cost"],
                            reference_type="SYSTEM",
                            reference_id=DEV_BUSINESS_ID,
                            created_by=DEV_USER_ID,
                            created_at=now_utc - timedelta(days=20),
                        )
                        stock_movements.append(sm)

                # Add sample IMEIs if provided
                if "imeis" in spec:
                    for imei_str in spec["imeis"]:
                        imei_obj = ImeiDevice(
                            id=uuid.uuid4(),
                            business_id=DEV_BUSINESS_ID,
                            branch_id=DEV_BRANCH_ID,
                            product_variant_id=v.id,
                            imei1=imei_str,
                            status="IN_STOCK",
                            created_at=now_utc - timedelta(days=15),
                        )
                        all_imeis.append(imei_obj)

        # 1. iPhone 16 Pro Max (Flagship Serialized)
        p_ip16pm = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_phones.id,
            brand_id=b_apple.id,
            sku="MBL-IP16PM",
            name="Apple iPhone 16 Pro Max",
            product_type="SERIALIZED_IMEI",
            is_active=True,
        )
        add_item(
            p_ip16pm,
            [
                {
                    "name": "256GB - Desert Titanium",
                    "barcode": "8941100010011",
                    "cost": Decimal("158000.0000"),
                    "price": Decimal("175000.0000"),
                    "stock": Decimal("8.0000"),
                    "imeis": ["358912110001011", "358912110001012", "358912110001013"],
                },
                {
                    "name": "256GB - Natural Titanium",
                    "barcode": "8941100010028",
                    "cost": Decimal("158000.0000"),
                    "price": Decimal("175000.0000"),
                    "stock": Decimal("6.0000"),
                    "imeis": ["358912110001021", "358912110001022"],
                },
                {
                    "name": "512GB - Black Titanium",
                    "barcode": "8941100010035",
                    "cost": Decimal("185000.0000"),
                    "price": Decimal("205000.0000"),
                    "stock": Decimal("3.0000"),  # Low stock
                    "imeis": ["358912110001031"],
                },
            ],
        )

        # 2. Samsung Galaxy S24 Ultra 5G
        p_s24u = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_phones.id,
            brand_id=b_samsung.id,
            sku="MBL-S24U",
            name="Samsung Galaxy S24 Ultra 5G",
            product_type="SERIALIZED_IMEI",
            is_active=True,
        )
        add_item(
            p_s24u,
            [
                {
                    "name": "12GB/256GB - Titanium Gray",
                    "barcode": "8941100010110",
                    "cost": Decimal("132000.0000"),
                    "price": Decimal("148000.0000"),
                    "stock": Decimal("10.0000"),
                    "imeis": ["354228120002011", "354228120002012"],
                },
                {
                    "name": "12GB/512GB - Titanium Black",
                    "barcode": "8941100010127",
                    "cost": Decimal("148000.0000"),
                    "price": Decimal("165000.0000"),
                    "stock": Decimal("5.0000"),
                    "imeis": ["354228120002021"],
                },
            ],
        )

        # 3. Google Pixel 9 Pro
        p_pix9p = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_phones.id,
            brand_id=b_google.id,
            sku="MBL-PIX9P",
            name="Google Pixel 9 Pro (Tensor G4)",
            product_type="SERIALIZED_IMEI",
            is_active=True,
        )
        add_item(
            p_pix9p,
            [
                {
                    "name": "128GB - Obsidian",
                    "barcode": "8941100010219",
                    "cost": Decimal("104000.0000"),
                    "price": Decimal("118000.0000"),
                    "stock": Decimal("6.0000"),
                    "imeis": ["353344130003011"],
                },
                {
                    "name": "256GB - Porcelain",
                    "barcode": "8941100010226",
                    "cost": Decimal("116000.0000"),
                    "price": Decimal("132000.0000"),
                    "stock": Decimal("4.0000"),
                    "imeis": ["353344130003021"],
                },
            ],
        )

        # 4. Xiaomi Redmi Note 13 Pro+ 5G
        p_rdm13 = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_phones.id,
            brand_id=b_xiaomi.id,
            sku="MBL-RDM-N13P",
            name="Xiaomi Redmi Note 13 Pro+ 5G",
            product_type="SERIALIZED_IMEI",
            is_active=True,
        )
        add_item(
            p_rdm13,
            [
                {
                    "name": "8GB/256GB - Midnight Black",
                    "barcode": "8941100010318",
                    "cost": Decimal("36500.0000"),
                    "price": Decimal("42000.0000"),
                    "stock": Decimal("15.0000"),
                    "imeis": ["864112140004011", "864112140004012"],
                },
                {
                    "name": "12GB/512GB - Aurora Purple",
                    "barcode": "8941100010325",
                    "cost": Decimal("42000.0000"),
                    "price": Decimal("48500.0000"),
                    "stock": Decimal("12.0000"),
                    "imeis": ["864112140004021"],
                },
            ],
        )

        # 5. OnePlus 12 5G
        p_op12 = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_phones.id,
            brand_id=b_oneplus.id,
            sku="MBL-OP12",
            name="OnePlus 12 5G (Snapdragon 8 Gen 3)",
            product_type="SERIALIZED_IMEI",
            is_active=True,
        )
        add_item(
            p_op12,
            [
                {
                    "name": "16GB/512GB - Silky Black",
                    "barcode": "8941100010417",
                    "cost": Decimal("81000.0000"),
                    "price": Decimal("92000.0000"),
                    "stock": Decimal("8.0000"),
                    "imeis": ["862211150005011"],
                },
                {
                    "name": "16GB/512GB - Flowy Emerald",
                    "barcode": "8941100010424",
                    "cost": Decimal("81000.0000"),
                    "price": Decimal("92000.0000"),
                    "stock": Decimal("7.0000"),
                    "imeis": ["862211150005021"],
                },
            ],
        )

        # 6. Samsung Galaxy A55 5G
        p_a55 = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_phones.id,
            brand_id=b_samsung.id,
            sku="MBL-SAMS-A55",
            name="Samsung Galaxy A55 5G (Awesome Iceblue)",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_a55,
            [
                {
                    "name": "Standard 8GB/128GB",
                    "barcode": "8941100010516",
                    "cost": Decimal("40000.0000"),
                    "price": Decimal("46500.0000"),
                    "stock": Decimal("14.0000"),
                }
            ],
        )

        # 7. Apple 20W USB-C Power Adapter
        p_apl_20w = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_chargers.id,
            brand_id=b_apple.id,
            sku="ACC-APL-20W",
            name="Apple 20W USB-C Power Adapter",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_apl_20w,
            [
                {
                    "name": "Standard White",
                    "barcode": "8941100020010",
                    "cost": Decimal("2200.0000"),
                    "price": Decimal("2850.0000"),
                    "stock": Decimal("65.0000"),
                }
            ],
        )

        # 8. Anker 735 GaNPrime 65W 3-Port Fast Charger
        p_ank_65w = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_chargers.id,
            brand_id=b_anker.id,
            sku="ACC-ANK-65W",
            name="Anker 735 GaNPrime 65W (2C1A)",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_ank_65w,
            [
                {
                    "name": "Standard Black",
                    "barcode": "8941100020027",
                    "cost": Decimal("3600.0000"),
                    "price": Decimal("4600.0000"),
                    "stock": Decimal("35.0000"),
                }
            ],
        )

        # 9. Samsung 45W Super Fast Power Adapter
        p_sam_45w = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_chargers.id,
            brand_id=b_samsung.id,
            sku="ACC-SAM-45W",
            name="Samsung 45W Super Fast Wall Charger",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_sam_45w,
            [
                {
                    "name": "Standard Black with Cable",
                    "barcode": "8941100020034",
                    "cost": Decimal("2600.0000"),
                    "price": Decimal("3400.0000"),
                    "stock": Decimal("40.0000"),
                }
            ],
        )

        # 10. Baseus Cafule 100W USB-C Braided Cable
        p_bas_100w = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_chargers.id,
            brand_id=b_baseus.id,
            sku="ACC-BAS-100WC",
            name="Baseus Cafule 100W USB-C Cable (2m)",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_bas_100w,
            [
                {
                    "name": "Standard Gray/Black",
                    "barcode": "8941100020041",
                    "cost": Decimal("600.0000"),
                    "price": Decimal("950.0000"),
                    "stock": Decimal("90.0000"),
                }
            ],
        )

        # 11. Anker PowerLine III USB-C to Lightning Cable
        p_ank_lgt = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_chargers.id,
            brand_id=b_anker.id,
            sku="ACC-ANK-LGT",
            name="Anker PowerLine III USB-C to Lightning (0.9m)",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_ank_lgt,
            [
                {
                    "name": "Standard White",
                    "barcode": "8941100020058",
                    "cost": Decimal("1200.0000"),
                    "price": Decimal("1750.0000"),
                    "stock": Decimal("50.0000"),
                }
            ],
        )

        # 12. Apple AirPods Pro 2 (USB-C)
        p_app2 = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_audio.id,
            brand_id=b_apple.id,
            sku="AUD-APL-APP2",
            name="Apple AirPods Pro 2 (USB-C MagSafe)",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_app2,
            [
                {
                    "name": "Standard White",
                    "barcode": "8941100030019",
                    "cost": Decimal("24500.0000"),
                    "price": Decimal("28500.0000"),
                    "stock": Decimal("18.0000"),
                }
            ],
        )

        # 13. Samsung Galaxy Buds3 Pro
        p_buds3 = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_audio.id,
            brand_id=b_samsung.id,
            sku="AUD-SAM-BUDS3P",
            name="Samsung Galaxy Buds3 Pro Blade Lights",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_buds3,
            [
                {
                    "name": "Silver Titanium",
                    "barcode": "8941100030026",
                    "cost": Decimal("19500.0000"),
                    "price": Decimal("23000.0000"),
                    "stock": Decimal("12.0000"),
                }
            ],
        )

        # 14. Sony WH-1000XM5 Wireless Headphones
        p_xm5 = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_audio.id,
            brand_id=b_sony.id,
            sku="AUD-SNY-XM5",
            name="Sony WH-1000XM5 ANC Wireless Headphones",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_xm5,
            [
                {
                    "name": "Midnight Black",
                    "barcode": "8941100030033",
                    "cost": Decimal("31000.0000"),
                    "price": Decimal("36500.0000"),
                    "stock": Decimal("2.0000"),  # Low stock alert!
                }
            ],
        )

        # 15. Anker Soundcore Space A40
        p_a40 = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_audio.id,
            brand_id=b_anker.id,
            sku="AUD-ANK-A40",
            name="Anker Soundcore Space A40 Hi-Res Earbuds",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_a40,
            [
                {
                    "name": "Standard Black",
                    "barcode": "8941100030040",
                    "cost": Decimal("6200.0000"),
                    "price": Decimal("7800.0000"),
                    "stock": Decimal("25.0000"),
                }
            ],
        )

        # 16. Anker 737 Power Bank (PowerCore 24K 140W)
        p_ank_737 = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_power.id,
            brand_id=b_anker.id,
            sku="PWR-ANK-737",
            name="Anker 737 Power Bank (24000mAh, 140W Smart Display)",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_ank_737,
            [
                {
                    "name": "Standard Black",
                    "barcode": "8941100040018",
                    "cost": Decimal("11800.0000"),
                    "price": Decimal("14500.0000"),
                    "stock": Decimal("15.0000"),
                }
            ],
        )

        # 17. Baseus MagSafe 10000mAh Power Bank
        p_bas_10k = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_power.id,
            brand_id=b_baseus.id,
            sku="PWR-BAS-10K",
            name="Baseus Magnetic MagSafe Power Bank (10000mAh 20W)",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_bas_10k,
            [
                {
                    "name": "White Magnetic",
                    "barcode": "8941100040025",
                    "cost": Decimal("2400.0000"),
                    "price": Decimal("3200.0000"),
                    "stock": Decimal("40.0000"),
                }
            ],
        )

        # 18. Remax RPP-520 20000mAh Fast Charging
        p_rmx_20k = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_power.id,
            brand_id=b_remax.id,
            sku="PWR-RMX-20K",
            name="Remax RPP-520 20000mAh 22.5W Power Bank",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_rmx_20k,
            [
                {
                    "name": "Blue/Black Dual Port",
                    "barcode": "8941100040032",
                    "cost": Decimal("1650.0000"),
                    "price": Decimal("2200.0000"),
                    "stock": Decimal("55.0000"),
                }
            ],
        )

        # 19. Spigen Ultra Hybrid Case for iPhone 16 Pro Max
        p_spg_case = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_protection.id,
            brand_id=b_spigen.id,
            sku="CAS-SPG-IP16PM",
            name="Spigen Ultra Hybrid Case (iPhone 16 Pro Max)",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_spg_case,
            [
                {
                    "name": "Crystal Clear Frost",
                    "barcode": "8941100050017",
                    "cost": Decimal("1950.0000"),
                    "price": Decimal("2900.0000"),
                    "stock": Decimal("45.0000"),
                }
            ],
        )

        # 20. Nillkin CamShield Pro for Galaxy S24 Ultra
        p_nlk_case = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_protection.id,
            brand_id=b_spigen.id,
            sku="CAS-NLK-S24U",
            name="Nillkin CamShield Pro Case (Galaxy S24 Ultra)",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_nlk_case,
            [
                {
                    "name": "Matte Black Slide Cover",
                    "barcode": "8941100050024",
                    "cost": Decimal("1200.0000"),
                    "price": Decimal("1850.0000"),
                    "stock": Decimal("30.0000"),
                }
            ],
        )

        # 21. 9D Full Glue Curved Tempered Glass
        p_9d_glass = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_protection.id,
            brand_id=None,
            sku="CAS-GLS-9D",
            name="9D Full Glue Curved Tempered Glass",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_9d_glass,
            [
                {
                    "name": "Universal HD Clear",
                    "barcode": "8941100050031",
                    "cost": Decimal("120.0000"),
                    "price": Decimal("350.0000"),
                    "stock": Decimal("120.0000"),
                }
            ],
        )

        # 22. Baseus Diamond Camera Lens Protector
        p_lens = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_protection.id,
            brand_id=b_baseus.id,
            sku="CAS-BAS-LENS",
            name="Baseus Diamond Camera Lens Protector Kit",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_lens,
            [
                {
                    "name": "Titanium Gray Rings",
                    "barcode": "8941100050048",
                    "cost": Decimal("320.0000"),
                    "price": Decimal("650.0000"),
                    "stock": Decimal("60.0000"),
                }
            ],
        )

        # 23. Baseus Gravitational Car Air Vent Mount
        p_carmount = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_mounts.id,
            brand_id=b_baseus.id,
            sku="ACC-BAS-CARM",
            name="Baseus Gravitational Metal Car Mount",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_carmount,
            [
                {
                    "name": "Dark Gray Air Vent Clamp",
                    "barcode": "8941100060016",
                    "cost": Decimal("800.0000"),
                    "price": Decimal("1250.0000"),
                    "stock": Decimal("28.0000"),
                }
            ],
        )

        # 24. Apple Watch Series 10 (46mm GPS)
        p_w10 = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_wearables.id,
            brand_id=b_apple.id,
            sku="WRB-APL-W10",
            name="Apple Watch Series 10 (46mm GPS)",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_w10,
            [
                {
                    "name": "Jet Black Aluminum Sport Band",
                    "barcode": "8941100070015",
                    "cost": Decimal("47000.0000"),
                    "price": Decimal("54000.0000"),
                    "stock": Decimal("5.0000"),
                }
            ],
        )

        # 25. Samsung Galaxy Watch 7 (44mm Bluetooth)
        p_gw7 = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_wearables.id,
            brand_id=b_samsung.id,
            sku="WRB-SAM-W7",
            name="Samsung Galaxy Watch 7 (44mm Bluetooth)",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_gw7,
            [
                {
                    "name": "Green Armor Aluminum",
                    "barcode": "8941100070022",
                    "cost": Decimal("27500.0000"),
                    "price": Decimal("32000.0000"),
                    "stock": Decimal("8.0000"),
                }
            ],
        )

        # 26. Display / Screen Replacement Service
        p_srv_screen = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_services.id,
            brand_id=None,
            sku="SRV-SCR-REP",
            name="Smartphone OLED Display Fitting & Repair Service",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_srv_screen,
            [
                {
                    "name": "Installation Labor & Warranty",
                    "barcode": "8941100080014",
                    "cost": Decimal("200.0000"),
                    "price": Decimal("1500.0000"),
                    "stock": Decimal("0.0000"),
                    "track_stock": False,
                }
            ],
        )

        # 27. Firmware Flashing & Backup Service
        p_srv_flash = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_services.id,
            brand_id=None,
            sku="SRV-FW-FLASH",
            name="Official Firmware Flash, Unbrick & Cloud Data Backup",
            product_type="STANDARD",
            is_active=True,
        )
        add_item(
            p_srv_flash,
            [
                {
                    "name": "Technician Service",
                    "barcode": "8941100080021",
                    "cost": Decimal("50.0000"),
                    "price": Decimal("800.0000"),
                    "stock": Decimal("0.0000"),
                    "track_stock": False,
                }
            ],
        )

        await session.flush()
        session.add_all(all_variants)
        await session.flush()
        session.add_all(all_imeis)
        session.add_all(stock_balances)
        session.add_all(stock_movements)
        await session.flush()

        print(f"Catalog seeded: {len(all_variants)} variants, {len(all_imeis)} serialized IMEIs, {len(stock_balances)} stock balances on Main Store.")

        print("[6/10] Seeding Financial Accounts (Vault, Drawer, Bank, bKash)...")
        safe_entity = FinancialAccount(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            account_name="Main Store Vault (Safe)",
            account_type="SAFE",
            opening_balance=Decimal("250000.0000"),
            current_balance=Decimal("385000.0000"),
            is_active=True,
        )
        drawer_entity = FinancialAccount(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            account_name="POS Terminal Register Drawer",
            account_type="CASH_DRAWER",
            opening_balance=Decimal("15000.0000"),
            current_balance=Decimal("42650.0000"),
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
            opening_balance=Decimal("500000.0000"),
            current_balance=Decimal("890000.0000"),
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
            opening_balance=Decimal("50000.0000"),
            current_balance=Decimal("125400.0000"),
            is_active=True,
        )
        petty_entity = FinancialAccount(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            account_name="Petty Cash Box",
            account_type="PETTY_CASH",
            opening_balance=Decimal("10000.0000"),
            current_balance=Decimal("14250.0000"),
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
            reference_no="TRF-20261118-001",
            note="Morning register float replenishment from safe",
            transfer_date=now_utc - timedelta(days=2),
            created_by=DEV_USER_ID,
        )
        trf2 = AccountTransfer(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            from_account_id=drawer_entity.id,
            to_account_id=bank_entity.id,
            amount=Decimal("50000.0000"),
            reference_no="TRF-20261119-002",
            note="Daily closing cash sales bank deposit",
            transfer_date=now_utc - timedelta(days=1),
            created_by=DEV_USER_ID,
        )
        session.add_all([trf1, trf2])
        await session.flush()

        print("[7/10] Seeding Operating Expenses & Recurring Vouchers...")
        cat_rent = ExpenseCategory(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Showroom Rent & Maintenance",
            code="RENT",
            description="Monthly lease, showroom rent, and market service charges",
            monthly_budget=Decimal("60000.0000"),
            is_active=True,
        )
        cat_util = ExpenseCategory(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Electricity & High-Speed Internet",
            code="UTIL",
            description="Commercial power, generator backup, and gigabit fiber",
            monthly_budget=Decimal("15000.0000"),
            is_active=True,
        )
        cat_staff = ExpenseCategory(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Staff Refreshment & Meals",
            code="TEA",
            description="Daily tea, evening snacks, and drinking water jars",
            monthly_budget=Decimal("6000.0000"),
            is_active=True,
        )
        session.add_all([cat_rent, cat_util, cat_staff])
        await session.flush()

        exp1 = Expense(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            voucher_no="EXP-20261115-0001",
            category_id=cat_rent.id,
            category=cat_rent.name,
            payment_account_id=safe_entity.id,
            payment_method="BANK",
            payee="Gulshan Shopping Arcade Ltd.",
            receipt_reference="RENT-NOV-2026",
            amount=Decimal("60000.0000"),
            tax_deductible=True,
            note="Showroom advance rent for November 2026",
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
            voucher_no="EXP-20261118-0002",
            category_id=cat_util.id,
            category=cat_util.name,
            payment_account_id=drawer_entity.id,
            payment_method="CASH",
            payee="DESCO Commercial Meter",
            receipt_reference="DESCO-77112",
            amount=Decimal("7850.0000"),
            tax_deductible=False,
            note="Showroom electricity bill payment",
            approval_status="APPROVED",
            approved_by=DEV_USER_ID,
            approved_at=now_utc - timedelta(days=2),
            created_by=DEV_USER_ID,
            created_at=now_utc - timedelta(days=2),
        )
        session.add_all([exp1, exp2])
        await session.flush()

        print("[8/10] Seeding Register Shifts (Yesterday closed & Today active)...")
        shift_yesterday = RegisterShift(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            user_id=USER_MANAGER_ID,
            status="CLOSED",
            opened_at=now_utc - timedelta(days=1, hours=9),
            closed_at=now_utc - timedelta(days=1, hours=1),
            opening_cash=Decimal("5000.0000"),
            closing_cash_expected=Decimal("23450.0000"),
            closing_cash_counted=Decimal("23450.0000"),
            cash_difference=Decimal("0.0000"),
            opening_notes="Opening morning float",
            closing_notes="Shift balanced accurately. All card & bKash slips checked.",
            denominations_json={"1000": 18, "500": 8, "100": 14, "50": 1},
            created_at=now_utc - timedelta(days=1, hours=9),
        )
        shift_today = RegisterShift(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            user_id=DEV_USER_ID,
            status="OPEN",
            opened_at=now_utc - timedelta(hours=3),
            closed_at=None,
            opening_cash=Decimal("5000.0000"),
            opening_notes="Active counter shift session",
            denominations_json={"1000": 3, "500": 3, "100": 5},
            created_at=now_utc - timedelta(hours=3),
        )
        session.add_all([shift_yesterday, shift_today])
        await session.flush()

        print("[9/10] Seeding Realistic Sales Transactions with Multi-tender...")
        # Map some variants for clean sales
        v_ip16_desert = all_variants[0]
        v_apl_charger = [v for v in all_variants if v.barcode == "8941100020010"][0]
        v_spg_case = [v for v in all_variants if v.barcode == "8941100050017"][0]
        v_glass = [v for v in all_variants if v.barcode == "8941100050031"][0]
        v_airpods = [v for v in all_variants if v.barcode == "8941100030019"][0]
        v_anker_bank = [v for v in all_variants if v.barcode == "8941100040018"][0]
        v_s24u = [v for v in all_variants if v.barcode == "8941100010110"][0]

        sales_data = [
            # Sale 1 (Yesterday): High-value sale (iPhone 16 Pro Max + 20W Charger + Spigen Case)
            {
                "receipt_no": "REC-20261119-MAIN-0001",
                "customer": c_shakil,
                "cashier_id": DEV_USER_ID,
                "created_at": now_utc - timedelta(days=1, hours=5),
                "items": [
                    (v_ip16_desert, Decimal("1.0"), Decimal("0.0")),
                    (v_apl_charger, Decimal("1.0"), Decimal("0.0")),
                    (v_spg_case, Decimal("1.0"), Decimal("0.0")),
                ],
                "tax_rate": Decimal("5.0"),
                "cart_discount": Decimal("1000.0"),  # VIP discount
                "payments": [
                    ("CARD", Decimal("100000.0000"), "VISA-Chip-8812"),
                    ("BKASH", Decimal("88725.0000"), "TRX-BK-99120"),
                ],
            },
            # Sale 2 (Yesterday): Accessories bundle (AirPods Pro 2 + 9D Glass)
            {
                "receipt_no": "REC-20261119-MAIN-0002",
                "customer": None,
                "cashier_id": DEV_USER_ID,
                "created_at": now_utc - timedelta(days=1, hours=3),
                "items": [
                    (v_airpods, Decimal("1.0"), Decimal("0.0")),
                    (v_glass, Decimal("2.0"), Decimal("0.0")),
                ],
                "tax_rate": Decimal("5.0"),
                "cart_discount": Decimal("0.0"),
                "payments": [
                    ("CASH", Decimal("30660.0000"), "Tendered 31,000, changed returned"),
                ],
            },
            # Sale 3 (Yesterday): Corporate Credit Sale (Farhana Yasmin buys Galaxy S24 Ultra on Due)
            {
                "receipt_no": "REC-20261119-MAIN-0003",
                "customer": c_farhana,
                "cashier_id": DEV_USER_ID,
                "created_at": now_utc - timedelta(days=1, hours=2),
                "items": [
                    (v_s24u, Decimal("1.0"), Decimal("0.0")),
                ],
                "tax_rate": Decimal("5.0"),
                "cart_discount": Decimal("0.0"),
                "payments": [
                    ("BANK", Decimal("50000.0000"), "Advance Bank Transfer"),
                ],
            },
            # Sale 4 (Today): Fast walk-in cash purchase (Anker 140W Power Bank + Baseus 100W Cable)
            {
                "receipt_no": "REC-20261120-MAIN-0001",
                "customer": None,
                "cashier_id": DEV_USER_ID,
                "created_at": now_utc - timedelta(hours=2),
                "items": [
                    (v_anker_bank, Decimal("1.0"), Decimal("0.0")),
                    (v_glass, Decimal("1.0"), Decimal("0.0")),
                ],
                "tax_rate": Decimal("5.0"),
                "cart_discount": Decimal("0.0"),
                "payments": [
                    ("CASH", Decimal("15592.5000"), "Exact Cash"),
                ],
            },
            # Sale 5 (Today): Screen Protector & Lens Ring fitting
            {
                "receipt_no": "REC-20261120-MAIN-0002",
                "customer": c_tariqul,
                "cashier_id": DEV_USER_ID,
                "created_at": now_utc - timedelta(hours=1),
                "items": [
                    (v_glass, Decimal("1.0"), Decimal("0.0")),
                ],
                "tax_rate": Decimal("5.0"),
                "cart_discount": Decimal("0.0"),
                "payments": [
                    ("BKASH", Decimal("367.5000"), "TRX-BK-77112"),
                ],
            },
        ]

        for s_spec in sales_data:
            sale_id = uuid.uuid4()
            subtotal = Decimal("0.0000")
            items_discount = Decimal("0.0000")
            sale_items = []

            for var, qty, disc in s_spec["items"]:
                line_sub = (qty * var.selling_price).quantize(Decimal("0.0001"))
                line_disc = disc.quantize(Decimal("0.0001"))
                line_tot = line_sub - line_disc
                subtotal += line_sub
                items_discount += line_disc

                si = SaleItem(
                    id=uuid.uuid4(),
                    sale_id=sale_id,
                    product_variant_id=var.id,
                    quantity=qty,
                    unit_price=var.selling_price,
                    unit_cost_snapshot=var.cost_price,
                    discount=line_disc,
                    line_total=line_tot,
                )
                sale_items.append(si)

                if var.track_stock:
                    sm = StockMovement(
                        id=uuid.uuid4(),
                        business_id=DEV_BUSINESS_ID,
                        branch_id=DEV_BRANCH_ID,
                        product_variant_id=var.id,
                        movement_type="SALE",
                        quantity_delta=-qty,
                        unit_cost=var.cost_price,
                        reference_type="SALE",
                        reference_id=sale_id,
                        created_by=s_spec["cashier_id"],
                        created_at=s_spec["created_at"],
                    )
                    session.add(sm)

            cart_disc = s_spec["cart_discount"].quantize(Decimal("0.0001"))
            total_disc = items_discount + cart_disc
            tax_rate = s_spec["tax_rate"]
            taxable_subtotal = max(Decimal("0.0000"), subtotal - total_disc)
            tax_total = (taxable_subtotal * (tax_rate / Decimal("100.0"))).quantize(Decimal("0.0001"))
            grand_total = (taxable_subtotal + tax_total).quantize(Decimal("0.0001"))

            paid_total = Decimal("0.0000")
            payment_entities = []
            for method, amount, ref in s_spec["payments"]:
                p_amt = amount.quantize(Decimal("0.0001"))
                paid_total += p_amt
                pt = PaymentTender(
                    id=uuid.uuid4(),
                    business_id=DEV_BUSINESS_ID,
                    sale_id=sale_id,
                    method=method,
                    amount=p_amt,
                    reference=ref,
                    status="CONFIRMED",
                    received_at=s_spec["created_at"],
                )
                payment_entities.append(pt)

            effective_paid = min(paid_total, grand_total)
            due_total = max(Decimal("0.0000"), grand_total - effective_paid)

            cust = s_spec["customer"]
            sale_entity = Sale(
                id=sale_id,
                business_id=DEV_BUSINESS_ID,
                branch_id=DEV_BRANCH_ID,
                receipt_no=s_spec["receipt_no"],
                customer_id=cust.id if cust else None,
                cashier_id=s_spec["cashier_id"],
                status="COMPLETED",
                subtotal=subtotal,
                discount_total=total_disc,
                tax_total=tax_total,
                grand_total=grand_total,
                paid_total=effective_paid,
                due_total=due_total,
                idempotency_key=str(uuid.uuid4()),
                notes="Standard mobile store sale",
                created_at=s_spec["created_at"],
            )
            session.add(sale_entity)
            session.add_all(sale_items)
            session.add_all(payment_entities)

        await session.flush()

        print("[10/10] Seeding Batches, Price Lists, Loyalty Tiers and Gift Cards...")
        # Inventory Batches on Main Store
        b1 = InventoryBatch(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            product_variant_id=v_apl_charger.id,
            batch_number="LOT-APL-2026-NOV",
            manufacturing_date=date.today() - timedelta(days=20),
            expiry_date=date.today() + timedelta(days=365),
            quantity_received=Decimal("50.0000"),
            quantity_on_hand=Decimal("45.0000"),
            cost_price=v_apl_charger.cost_price,
            is_active=True,
        )
        b2 = InventoryBatch(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            product_variant_id=v_anker_bank.id,
            batch_number="LOT-ANK-2026-EXP",
            manufacturing_date=date.today() - timedelta(days=90),
            expiry_date=date.today() + timedelta(days=15),  # Expiring soon
            quantity_received=Decimal("20.0000"),
            quantity_on_hand=Decimal("14.0000"),
            cost_price=v_anker_bank.cost_price,
            is_active=True,
        )
        session.add_all([b1, b2])

        # Damaged Stock write-off record
        dam1 = DamagedStockRecord(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            product_variant_id=v_glass.id,
            voucher_no="DAM-20261118-001",
            quantity=Decimal("3.0000"),
            unit_cost=v_glass.cost_price,
            total_loss=v_glass.cost_price * Decimal("3.0000"),
            reason="BROKEN",
            disposal_method="WRITTEN_OFF",
            notes="Tempered glass cracked during display box unboxing",
            reported_by=DEV_USER_ID,
            approved_by=DEV_USER_ID,
            created_at=now_utc - timedelta(days=2),
        )
        session.add(dam1)

        # Stock Reservation
        res1 = StockReservation(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            product_variant_id=v_ip16_desert.id,
            quantity=Decimal("1.0000"),
            reference_type="QUOTATION",
            reference_id=uuid.uuid4(),
            status="ACTIVE",
            reserved_until=now_utc + timedelta(days=2),
            created_by=DEV_USER_ID,
        )
        session.add(res1)

        # Loyalty Tiers
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

        t_silver = MembershipTier(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Silver Gadget Club",
            code="SILVER",
            min_spend=Decimal("20000.0000"),
            points_multiplier=Decimal("1.25"),
            discount_pct=Decimal("3.00"),
            perks_description="1.25x point earnings + 3% discount on mobile accessories",
            is_active=True,
        )
        t_gold = MembershipTier(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Gold Tech Elite",
            code="GOLD",
            min_spend=Decimal("60000.0000"),
            points_multiplier=Decimal("1.50"),
            discount_pct=Decimal("5.00"),
            perks_description="1.5x points + 5% flat store discount + free screen protector installation",
            is_active=True,
        )
        t_plat = MembershipTier(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Platinum VIP Gadgeteer",
            code="PLATINUM",
            min_spend=Decimal("150000.0000"),
            points_multiplier=Decimal("2.00"),
            discount_pct=Decimal("8.00"),
            perks_description="2x double points + 8% VIP discount + lifetime free tempered glass replacement",
            is_active=True,
        )
        session.add_all([t_silver, t_gold, t_plat])

        # Promotions
        promo1 = Promotion(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Festive Gadget Fest (10% Off Accessories)",
            code="GADGET10",
            discount_type="PERCENTAGE",
            discount_value=Decimal("10.0000"),
            min_spend=Decimal("1000.0000"),
            max_discount_cap=Decimal("1000.0000"),
            usage_limit=500,
            times_used=18,
            valid_from=date.today() - timedelta(days=30),
            valid_until=date.today() + timedelta(days=90),
            is_active=True,
        )
        session.add(promo1)

        # Gift Card
        pin_hash = GiftCardService.hash_pin("1234")
        gc = GiftCard(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            card_number="GC-APEX-2026-5000",
            pin_hash=pin_hash,
            initial_balance=Decimal("5000.0000"),
            current_balance=Decimal("5000.0000"),
            status="ACTIVE",
            recipient_name="Shakil Khan",
            recipient_phone="01711122233",
            expires_at=now_utc + timedelta(days=365),
        )
        session.add(gc)

        await session.commit()
        print("=" * 70)
        print("MOBILE & ACCESSORIES DATASET SUCCESSFULLY SEEDED (SINGLE MAIN STORE)!")
        print("=" * 70)


async def main() -> None:
    print("=" * 70)
    print("RETAIL POS: WIPING DATABASE AND SEEDING MODERN MOBILE STORE")
    print("=" * 70)
    await reset_schema()
    run_migrations()
    await seed_mobile_store_data()
    print("=" * 70)
    print("DONE! DATABASE IS READY WITH SINGLE MAIN STORE & MOBILE CATALOG.")
    print("=" * 70)


if __name__ == "__main__":
    asyncio.run(main())
