"""Database reset and comprehensive demo data seed script.

Wipes the database schema, executes all Alembic migrations to head, and populates
realistic demonstration data covering:
- Multi-branch structure (Main Store, Dhanmondi, Uttara)
- Cashiers, admins, and active memberships
- Categories, brands, and diverse catalog (standard, variants, serialized IMEI, services)
- Inventory balances across branches with low-stock and out-of-stock alert scenarios
- Suppliers, purchase orders, and supplier receipts
- Customer profiles with credit limits and outstanding receivables
- Register shifts (closed balanced shift and currently open shift)
- Historical and today's sales with realistic payment distributions (Cash, Card, bKash, Nagad, Due)
- Inter-branch inventory transfers (Received and In-Transit)
"""

import asyncio
import os
import sys
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

# Ensure backend directory is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from alembic.config import Config
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

from alembic import command
from app.config import get_settings
from app.database import get_session_maker
from app.modules.business.models import Branch, Business
from app.modules.catalog.models import Brand, Category, ImeiDevice, Product, ProductVariant
from app.modules.identity.models import Membership, User
from app.modules.inventory.models import (
    StockBalance,
    StockMovement,
    StockTransfer,
    StockTransferItem,
)
from app.modules.purchasing.models import Purchase, PurchaseItem, Supplier
from app.modules.sales.models import Customer, PaymentTender, Sale, SaleItem
from app.modules.shifts.models import RegisterShift
from app.shared.auth import DEV_BUSINESS_ID, DEV_USER_ID

DEV_BRANCH_ID = uuid.UUID("00000000-0000-0000-0000-000000000002")
BRANCH_DHAN_ID = uuid.UUID("00000000-0000-0000-0000-000000000003")
BRANCH_UTTR_ID = uuid.UUID("00000000-0000-0000-0000-000000000004")

USER_RAHIM_ID = uuid.UUID("00000000-0000-0000-0000-000000000010")
USER_KARIM_ID = uuid.UUID("00000000-0000-0000-0000-000000000011")


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


async def seed_data() -> None:
    """Seeds comprehensive demo dataset with full relational and financial ledger integrity."""
    session_maker = get_session_maker()
    now_utc = datetime.now(UTC).replace(tzinfo=None)

    async with session_maker() as session:
        print("Seeding business and multi-branch infrastructure...")
        # 1. Business
        biz = Business(
            id=DEV_BUSINESS_ID,
            name="Retail POS Store (Development)",
            legal_name="Smart Retail Tech Ltd.",
            timezone="Asia/Dhaka",
            currency="BDT",
            is_active=True,
            created_at=now_utc - timedelta(days=30),
        )
        session.add(biz)
        await session.flush()

        # 2. Branches
        br_main = Branch(
            id=DEV_BRANCH_ID,
            business_id=DEV_BUSINESS_ID,
            name="Main Store (Gulshan)",
            code="MAIN",
            address="House 12, Road 4, Gulshan-1, Dhaka",
            phone="+880 1711 000001",
            is_active=True,
            created_at=now_utc - timedelta(days=30),
        )
        br_dhan = Branch(
            id=BRANCH_DHAN_ID,
            business_id=DEV_BUSINESS_ID,
            name="Dhanmondi Branch",
            code="DHAN",
            address="Plot 24, Satmasjid Road, Dhanmondi, Dhaka",
            phone="+880 1711 000002",
            is_active=True,
            created_at=now_utc - timedelta(days=25),
        )
        br_uttr = Branch(
            id=BRANCH_UTTR_ID,
            business_id=DEV_BUSINESS_ID,
            name="Uttara Outlet",
            code="UTTR",
            address="Sector 3, Jashimuddin Avenue, Uttara, Dhaka",
            phone="+880 1711 000003",
            is_active=True,
            created_at=now_utc - timedelta(days=20),
        )
        session.add_all([br_main, br_dhan, br_uttr])
        await session.flush()

        # 3. Users & Memberships
        print("Seeding users and cashiers...")
        u_admin = User(
            id=DEV_USER_ID,
            username="dev_cashier",
            email="admin@pos.local",
            display_name="Admin Cashier",
            phone="01700000000",
            password_hash="dev_dummy_hash_not_for_prod",
            is_active=True,
            created_at=now_utc - timedelta(days=30),
        )
        u_rahim = User(
            id=USER_RAHIM_ID,
            username="rahim",
            email="rahim@pos.local",
            display_name="Rahim Ahmed",
            phone="01711223344",
            password_hash="dev_dummy_hash_not_for_prod",
            is_active=True,
            created_at=now_utc - timedelta(days=28),
        )
        u_karim = User(
            id=USER_KARIM_ID,
            username="karim",
            email="karim@pos.local",
            display_name="Karim Ullah",
            phone="01811223344",
            password_hash="dev_dummy_hash_not_for_prod",
            is_active=True,
            created_at=now_utc - timedelta(days=28),
        )
        session.add_all([u_admin, u_rahim, u_karim])
        await session.flush()

        m_admin = Membership(business_id=DEV_BUSINESS_ID, user_id=DEV_USER_ID, status="ACTIVE")
        m_rahim = Membership(business_id=DEV_BUSINESS_ID, user_id=USER_RAHIM_ID, status="ACTIVE")
        m_karim = Membership(business_id=DEV_BUSINESS_ID, user_id=USER_KARIM_ID, status="ACTIVE")
        session.add_all([m_admin, m_rahim, m_karim])
        await session.flush()

        # 4. Categories & Brands
        print("Seeding categories and brands...")
        cat_bev = Category(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Beverages")
        cat_snk = Category(
            id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Snacks & Confectionery"
        )
        cat_dry = Category(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Dairy & Bakery")
        cat_per = Category(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Personal Care")
        cat_hsh = Category(
            id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Household & Cleaning"
        )
        cat_app = Category(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Apparel & Fashion")
        cat_ele = Category(
            id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Electronics & Mobile"
        )
        session.add_all([cat_bev, cat_snk, cat_dry, cat_per, cat_hsh, cat_app, cat_ele])
        await session.flush()

        b_akij = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Akij Food & Beverage")
        b_pran = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="PRAN")
        b_nest = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Nestlé")
        b_unil = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Unilever")
        b_squa = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Square Consumer")
        b_aaro = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Aarong Dairy")
        b_sams = Brand(id=uuid.uuid4(), business_id=DEV_BUSINESS_ID, name="Samsung")
        session.add_all([b_akij, b_pran, b_nest, b_unil, b_squa, b_aaro, b_sams])
        await session.flush()

        # 5. Suppliers
        print("Seeding suppliers...")
        sup_akij = Supplier(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Akij Food & Beverage Distribution",
            contact_person="Kamal Hossain",
            phone="+880 1812 345678",
            email="orders@akijfood.com",
            address="Akij House, 198 Bir Uttam Mir Shawkat Sarak, Dhaka",
        )
        sup_pran = Supplier(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="PRAN-RFL Consumer Goods",
            contact_person="Mizanur Rahman",
            phone="+880 1823 456789",
            email="supply@pranrfl.com",
            address="PRAN-RFL Center, Middle Badda, Dhaka",
        )
        sup_unil = Supplier(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Unilever Bangladesh Distribution",
            contact_person="Sultana Razia",
            phone="+880 1834 567890",
            email="corporate@unilever.bd",
            address="ZN Tower, Gulshan Avenue, Dhaka",
        )
        sup_squa = Supplier(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Square Consumer Products Ltd.",
            contact_person="Asif Mahmud",
            phone="+880 1845 678901",
            email="sales@squareconsumer.com",
            address="Square Centre, 48 Mohakhali C/A, Dhaka",
        )
        sup_tech = Supplier(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Smart Technologies BD Ltd.",
            contact_person="Zubair Ahmed",
            phone="+880 1856 789012",
            email="tech@smartbd.com",
            address="Jahangir Tower, Karwan Bazar, Dhaka",
        )
        session.add_all([sup_akij, sup_pran, sup_unil, sup_squa, sup_tech])
        await session.flush()

        # 6. Customers with credit limits
        print("Seeding customers and credit limits...")
        c_shakil = Customer(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Md. Shakil Khan",
            phone="01711122233",
            email="shakil.khan@gmail.com",
            address="Gulshan-1, Dhaka",
            credit_limit=Decimal("15000.0000"),
            is_active=True,
        )
        c_farhana = Customer(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Farhana Yasmin",
            phone="01811223344",
            email="farhana.y@gmail.com",
            address="Banani DOHS, Dhaka",
            credit_limit=Decimal("25000.0000"),
            is_active=True,
        )
        c_tariqul = Customer(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Tariqul Islam",
            phone="01911334455",
            email="tariqul.islam@yahoo.com",
            address="Dhanmondi 8/A, Dhaka",
            credit_limit=Decimal("10000.0000"),
            is_active=True,
        )
        c_nasrin = Customer(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Nasrin Akter",
            phone="01611445566",
            email="nasrin.akter@hotmail.com",
            address="Uttara Sector 7, Dhaka",
            credit_limit=Decimal("20000.0000"),
            is_active=True,
        )
        c_arif = Customer(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            name="Arifur Rahman",
            phone="01511556677",
            email="arif.rahman@outlook.com",
            address="Mirpur-10, Dhaka",
            credit_limit=Decimal("5000.0000"),
            is_active=True,
        )
        session.add_all([c_shakil, c_farhana, c_tariqul, c_nasrin, c_arif])
        await session.flush()

        # 7. Products & Product Variants
        print("Seeding catalog items (standard, variants, serialized IMEI, services)...")
        # Standard Items
        p_mojo = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_bev.id,
            brand_id=b_akij.id,
            sku="BEV-MOJO-250",
            name="Mojo Cola 250ml",
            product_type="STANDARD",
            is_active=True,
        )
        p_frooto = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_bev.id,
            brand_id=b_pran.id,
            sku="BEV-FROOTO-250",
            name="Pran Frooto Mango 250ml",
            product_type="STANDARD",
            is_active=True,
        )
        p_speed = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_bev.id,
            brand_id=b_akij.id,
            sku="BEV-SPEED-250",
            name="Speed Energy Drink 250ml",
            product_type="STANDARD",
            is_active=True,
        )
        p_kitkat = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_snk.id,
            brand_id=b_nest.id,
            sku="SNK-KITKAT-4F",
            name="KitKat 4 Finger 41.5g",
            product_type="STANDARD",
            is_active=True,
        )
        p_maggi = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_snk.id,
            brand_id=b_nest.id,
            sku="SNK-MAGGI-8P",
            name="Maggi 2-Minute Noodles (8-Pack)",
            product_type="STANDARD",
            is_active=True,
        )
        p_ghee = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_dry.id,
            brand_id=b_aaro.id,
            sku="DRY-GHEE-400",
            name="Aarong Dairy Pure Ghee 400g",
            product_type="STANDARD",
            is_active=True,
        )
        p_oil = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_snk.id,
            brand_id=b_squa.id,
            sku="GRO-RADHUNI-500",
            name="Radhuni Pure Mustard Oil 500ml",
            product_type="STANDARD",
            is_active=True,
        )
        p_dettol = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_per.id,
            brand_id=b_unil.id,
            sku="PER-DETTOL-100",
            name="Dettol Original Soap 100g",
            product_type="STANDARD",
            is_active=True,
        )
        p_vim = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_hsh.id,
            brand_id=b_unil.id,
            sku="HSH-VIM-500",
            name="Vim Dishwash Liquid 500ml",
            product_type="STANDARD",
            is_active=True,
        )
        p_surf = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_hsh.id,
            brand_id=b_unil.id,
            sku="HSH-SURF-1KG",
            name="Surf Excel Detergent 1kg",
            product_type="STANDARD",
            is_active=True,
        )

        # Multi-Variant Item (Polo Shirt)
        p_polo = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_app.id,
            brand_id=None,
            sku="APP-POLO-SHIRT",
            name="Premium Pique Cotton Polo Shirt",
            product_type="VARIANT",
            is_active=True,
        )

        # Serialized IMEI Item (Samsung Smartphone)
        p_phone = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=cat_ele.id,
            brand_id=b_sams.id,
            sku="ELE-SAMS-A15",
            name="Samsung Galaxy A15 (128GB)",
            product_type="SERIALIZED_IMEI",
            is_active=True,
        )

        # Non-inventory service
        p_gift = Product(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            category_id=None,
            brand_id=None,
            sku="SRV-GIFT-WRAP",
            name="Gift Packaging & Ribbon Service",
            product_type="STANDARD",
            is_active=True,
        )

        session.add_all(
            [
                p_mojo,
                p_frooto,
                p_speed,
                p_kitkat,
                p_maggi,
                p_ghee,
                p_oil,
                p_dettol,
                p_vim,
                p_surf,
                p_polo,
                p_phone,
                p_gift,
            ]
        )
        await session.flush()

        # Product Variants
        v_mojo = ProductVariant(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            product_id=p_mojo.id,
            name="Standard",
            barcode="8941100123456",
            cost_price=Decimal("15.0000"),
            selling_price=Decimal("20.0000"),
            track_stock=True,
            is_active=True,
        )
        v_frooto = ProductVariant(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            product_id=p_frooto.id,
            name="Standard",
            barcode="8941100234567",
            cost_price=Decimal("22.0000"),
            selling_price=Decimal("30.0000"),
            track_stock=True,
            is_active=True,
        )
        v_speed = ProductVariant(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            product_id=p_speed.id,
            name="Standard",
            barcode="8941100345678",
            cost_price=Decimal("28.0000"),
            selling_price=Decimal("35.0000"),
            track_stock=True,
            is_active=True,
        )
        v_kitkat = ProductVariant(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            product_id=p_kitkat.id,
            name="Standard",
            barcode="8941100456789",
            cost_price=Decimal("75.0000"),
            selling_price=Decimal("100.0000"),
            track_stock=True,
            is_active=True,
        )
        v_maggi = ProductVariant(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            product_id=p_maggi.id,
            name="Standard",
            barcode="8941100567890",
            cost_price=Decimal("150.0000"),
            selling_price=Decimal("180.0000"),
            track_stock=True,
            is_active=True,
        )
        v_ghee = ProductVariant(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            product_id=p_ghee.id,
            name="Standard",
            barcode="8941100678901",
            cost_price=Decimal("580.0000"),
            selling_price=Decimal("680.0000"),
            track_stock=True,
            is_active=True,
        )
        v_oil = ProductVariant(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            product_id=p_oil.id,
            name="Standard",
            barcode="8941100789012",
            cost_price=Decimal("140.0000"),
            selling_price=Decimal("165.0000"),
            track_stock=True,
            is_active=True,
        )
        v_dettol = ProductVariant(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            product_id=p_dettol.id,
            name="Standard",
            barcode="8941100890123",
            cost_price=Decimal("48.0000"),
            selling_price=Decimal("60.0000"),
            track_stock=True,
            is_active=True,
        )
        v_vim = ProductVariant(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            product_id=p_vim.id,
            name="Standard",
            barcode="8941100901234",
            cost_price=Decimal("115.0000"),
            selling_price=Decimal("140.0000"),
            track_stock=True,
            is_active=True,
        )
        v_surf = ProductVariant(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            product_id=p_surf.id,
            name="Standard",
            barcode="8941101012345",
            cost_price=Decimal("220.0000"),
            selling_price=Decimal("260.0000"),
            track_stock=True,
            is_active=True,
        )

        # Polo Variants
        v_polo_m = ProductVariant(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            product_id=p_polo.id,
            name="Navy Blue - Medium",
            barcode="8941102000020",
            cost_price=Decimal("350.0000"),
            selling_price=Decimal("550.0000"),
            track_stock=True,
            is_active=True,
        )
        v_polo_l = ProductVariant(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            product_id=p_polo.id,
            name="Navy Blue - Large",
            barcode="8941102000030",
            cost_price=Decimal("350.0000"),
            selling_price=Decimal("550.0000"),
            track_stock=True,
            is_active=True,
        )

        # Smartphone Variant
        v_phone = ProductVariant(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            product_id=p_phone.id,
            name="Black (128GB)",
            barcode="8941103000010",
            cost_price=Decimal("16500.0000"),
            selling_price=Decimal("19999.0000"),
            track_stock=True,
            is_active=True,
        )

        # Gift wrap
        v_gift = ProductVariant(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            product_id=p_gift.id,
            name="Standard Service",
            barcode="8941104000010",
            cost_price=Decimal("10.0000"),
            selling_price=Decimal("50.0000"),
            track_stock=False,
            is_active=True,
        )

        variants_all = [
            v_mojo,
            v_frooto,
            v_speed,
            v_kitkat,
            v_maggi,
            v_ghee,
            v_oil,
            v_dettol,
            v_vim,
            v_surf,
            v_polo_m,
            v_polo_l,
            v_phone,
            v_gift,
        ]
        session.add_all(variants_all)
        await session.flush()

        # Serialized IMEI Devices
        imei_1 = ImeiDevice(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            product_variant_id=v_phone.id,
            imei1="356789123456781",
            status="IN_STOCK",
        )
        imei_2 = ImeiDevice(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            product_variant_id=v_phone.id,
            imei1="356789123456782",
            status="IN_STOCK",
        )
        imei_3 = ImeiDevice(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            product_variant_id=v_phone.id,
            imei1="356789123456783",
            status="IN_STOCK",
        )
        session.add_all([imei_1, imei_2, imei_3])
        await session.flush()

        # 8. Stock Balances & Initial Movement Ledger
        print("Seeding stock balances and initial movement ledgers across branches...")
        # Main Store Balances:
        # High stock: Mojo (150), Frooto (120), Speed (80), KitKat (60), Maggi (45), Dettol (90), Oil (50), Polo M (35), Polo L (40), Phone (3)
        # Low stock (<5): Aarong Ghee (4), Vim Liquid (3) -> Low Stock Alerts!
        # Out of Stock (0): Surf Excel (0) -> Out of Stock Alert!
        stock_specs_main = [
            (v_mojo, Decimal("150.0000")),
            (v_frooto, Decimal("120.0000")),
            (v_speed, Decimal("80.0000")),
            (v_kitkat, Decimal("60.0000")),
            (v_maggi, Decimal("45.0000")),
            (v_ghee, Decimal("4.0000")),  # Low stock
            (v_oil, Decimal("50.0000")),
            (v_dettol, Decimal("90.0000")),
            (v_vim, Decimal("3.0000")),  # Low stock
            (v_surf, Decimal("0.0000")),  # Out of stock
            (v_polo_m, Decimal("35.0000")),
            (v_polo_l, Decimal("40.0000")),
            (v_phone, Decimal("3.0000")),
        ]

        for variant, qty in stock_specs_main:
            sb = StockBalance(
                business_id=DEV_BUSINESS_ID,
                branch_id=DEV_BRANCH_ID,
                product_variant_id=variant.id,
                quantity_on_hand=qty,
            )
            session.add(sb)
            if qty > 0:
                sm = StockMovement(
                    id=uuid.uuid4(),
                    business_id=DEV_BUSINESS_ID,
                    branch_id=DEV_BRANCH_ID,
                    product_variant_id=variant.id,
                    movement_type="OPENING_BALANCE",
                    quantity_delta=qty,
                    unit_cost=variant.cost_price,
                    reference_type="SYSTEM",
                    reference_id=DEV_BUSINESS_ID,
                    created_by=DEV_USER_ID,
                    created_at=now_utc - timedelta(days=20),
                )
                session.add(sm)

        # Dhanmondi Branch Balances (for Multi-Store testing):
        stock_specs_dhan = [
            (v_mojo, Decimal("50.0000")),
            (v_frooto, Decimal("40.0000")),
            (v_kitkat, Decimal("30.0000")),
            (v_dettol, Decimal("25.0000")),
            (v_polo_m, Decimal("15.0000")),
        ]
        for variant, qty in stock_specs_dhan:
            sb = StockBalance(
                business_id=DEV_BUSINESS_ID,
                branch_id=BRANCH_DHAN_ID,
                product_variant_id=variant.id,
                quantity_on_hand=qty,
            )
            session.add(sb)
            sm = StockMovement(
                id=uuid.uuid4(),
                business_id=DEV_BUSINESS_ID,
                branch_id=BRANCH_DHAN_ID,
                product_variant_id=variant.id,
                movement_type="OPENING_BALANCE",
                quantity_delta=qty,
                unit_cost=variant.cost_price,
                reference_type="SYSTEM",
                reference_id=DEV_BUSINESS_ID,
                created_by=DEV_USER_ID,
                created_at=now_utc - timedelta(days=20),
            )
            session.add(sm)

        await session.flush()

        # 9. Purchases & Received Goods
        print("Seeding purchase orders and vendor receipts...")
        po1 = Purchase(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            supplier_id=sup_akij.id,
            reference_no="PO-20261101-0001",
            status="RECEIVED",
            subtotal=Decimal("5800.0000"),
            discount=Decimal("0.0000"),
            total=Decimal("5800.0000"),
            paid_total=Decimal("5800.0000"),
            notes="Opening beverage stock delivery",
            created_by=DEV_USER_ID,
            created_at=now_utc - timedelta(days=5),
        )
        session.add(po1)
        await session.flush()

        pi1_1 = PurchaseItem(
            id=uuid.uuid4(),
            purchase_id=po1.id,
            product_variant_id=v_mojo.id,
            quantity=Decimal("200.0000"),
            unit_cost=Decimal("15.0000"),
            line_total=Decimal("3000.0000"),
        )
        pi1_2 = PurchaseItem(
            id=uuid.uuid4(),
            purchase_id=po1.id,
            product_variant_id=v_speed.id,
            quantity=Decimal("100.0000"),
            unit_cost=Decimal("28.0000"),
            line_total=Decimal("2800.0000"),
        )
        session.add_all([pi1_1, pi1_2])

        po2 = Purchase(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            supplier_id=sup_unil.id,
            reference_no="PO-20261102-0002",
            status="RECEIVED",
            subtotal=Decimal("10550.0000"),
            discount=Decimal("200.0000"),
            total=Decimal("10350.0000"),
            paid_total=Decimal("10350.0000"),
            notes="Personal care & hygiene supplies",
            created_by=DEV_USER_ID,
            created_at=now_utc - timedelta(days=3),
        )
        session.add(po2)
        await session.flush()

        pi2_1 = PurchaseItem(
            id=uuid.uuid4(),
            purchase_id=po2.id,
            product_variant_id=v_dettol.id,
            quantity=Decimal("100.0000"),
            unit_cost=Decimal("48.0000"),
            line_total=Decimal("4800.0000"),
        )
        pi2_2 = PurchaseItem(
            id=uuid.uuid4(),
            purchase_id=po2.id,
            product_variant_id=v_vim.id,
            quantity=Decimal("50.0000"),
            unit_cost=Decimal("115.0000"),
            line_total=Decimal("5750.0000"),
        )
        session.add_all([pi2_1, pi2_2])
        await session.flush()

        # 10. Register Shifts (Yesterday closed & Today open)
        print("Seeding register shifts...")
        shift_yesterday = RegisterShift(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            branch_id=DEV_BRANCH_ID,
            user_id=USER_RAHIM_ID,
            status="CLOSED",
            opened_at=now_utc - timedelta(days=1, hours=8),
            closed_at=now_utc - timedelta(days=1, hours=1),
            opening_cash=Decimal("5000.0000"),
            closing_cash_expected=Decimal("11250.0000"),
            closing_cash_counted=Decimal("11250.0000"),
            cash_difference=Decimal("0.0000"),
            opening_notes="Opening morning register float",
            closing_notes="Drawer balanced accurately. No variance.",
            denominations_json={"1000": 8, "500": 6, "100": 2, "50": 1},
            created_at=now_utc - timedelta(days=1, hours=8),
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
            opening_notes="Active cashier register session",
            denominations_json={"1000": 3, "500": 3, "100": 5},
            created_at=now_utc - timedelta(hours=3),
        )
        session.add_all([shift_yesterday, shift_today])
        await session.flush()

        # 11. Historical & Today Sales Transactions
        print("Seeding sales transactions and diverse payment distributions...")

        sales_data = [
            # Sale 1 (3 days ago): Cash sale
            {
                "receipt_no": "REC-20261101-MAIN-0001",
                "customer": None,
                "cashier_id": USER_RAHIM_ID,
                "created_at": now_utc - timedelta(days=3, hours=5),
                "items": [(v_mojo, Decimal("2.0"), Decimal("0.0")), (v_kitkat, Decimal("1.0"), Decimal("0.0"))],
                "tax_rate": Decimal("5.0"),
                "cart_discount": Decimal("0.0"),
                "payments": [("CASH", Decimal("147.0000"), "Exact Cash")],
            },
            # Sale 2 (3 days ago): Card sale
            {
                "receipt_no": "REC-20261101-MAIN-0002",
                "customer": None,
                "cashier_id": USER_RAHIM_ID,
                "created_at": now_utc - timedelta(days=3, hours=3),
                "items": [(v_maggi, Decimal("2.0"), Decimal("0.0")), (v_frooto, Decimal("2.0"), Decimal("0.0"))],
                "tax_rate": Decimal("5.0"),
                "cart_discount": Decimal("0.0"),
                "payments": [("CARD", Decimal("441.0000"), "VISA-4242")],
            },
            # Sale 3 (2 days ago): bKash sale
            {
                "receipt_no": "REC-20261102-MAIN-0001",
                "customer": None,
                "cashier_id": USER_KARIM_ID,
                "created_at": now_utc - timedelta(days=2, hours=6),
                "items": [(v_polo_m, Decimal("1.0"), Decimal("0.0")), (v_mojo, Decimal("2.0"), Decimal("0.0"))],
                "tax_rate": Decimal("5.0"),
                "cart_discount": Decimal("0.0"),
                "payments": [("BKASH", Decimal("619.5000"), "TRX-BK-98124")],
            },
            # Sale 4 (2 days ago): Nagad sale
            {
                "receipt_no": "REC-20261102-MAIN-0002",
                "customer": None,
                "cashier_id": USER_KARIM_ID,
                "created_at": now_utc - timedelta(days=2, hours=4),
                "items": [(v_oil, Decimal("2.0"), Decimal("0.0")), (v_dettol, Decimal("3.0"), Decimal("0.0"))],
                "tax_rate": Decimal("5.0"),
                "cart_discount": Decimal("10.0"),
                "payments": [("NAGAD", Decimal("525.0000"), "TRX-NG-34190")],
            },
            # Sale 5 (Yesterday): Split Tender (Cash + bKash)
            {
                "receipt_no": "REC-20261103-MAIN-0001",
                "customer": None,
                "cashier_id": USER_RAHIM_ID,
                "created_at": now_utc - timedelta(days=1, hours=6),
                "items": [(v_speed, Decimal("5.0"), Decimal("0.0")), (v_kitkat, Decimal("4.0"), Decimal("0.0"))],
                "tax_rate": Decimal("5.0"),
                "cart_discount": Decimal("0.0"),
                "payments": [("CASH", Decimal("300.0000"), "Cash part"), ("BKASH", Decimal("303.7500"), "TRX-BK-11234")],
            },
            # Sale 6 (Yesterday - Customer Credit Due Sale!)
            # Shakil Khan buys Ghee and Mustard Oil with ৳ 2,000 partial payment and remainder on DUE
            {
                "receipt_no": "REC-20261103-MAIN-0002",
                "customer": c_shakil,
                "cashier_id": USER_RAHIM_ID,
                "created_at": now_utc - timedelta(days=1, hours=4),
                "items": [(v_ghee, Decimal("2.0"), Decimal("0.0")), (v_oil, Decimal("3.0"), Decimal("0.0"))],
                "tax_rate": Decimal("5.0"),
                "cart_discount": Decimal("0.0"),
                "payments": [("CASH", Decimal("1000.0000"), "Deposit")],
            },
            # Sale 7 (Yesterday - Full Due Credit Sale!)
            # Farhana Yasmin buys 4 Polo shirts on full store credit (DUE)
            {
                "receipt_no": "REC-20261103-MAIN-0003",
                "customer": c_farhana,
                "cashier_id": USER_RAHIM_ID,
                "created_at": now_utc - timedelta(days=1, hours=2),
                "items": [(v_polo_m, Decimal("2.0"), Decimal("0.0")), (v_polo_l, Decimal("2.0"), Decimal("0.0"))],
                "tax_rate": Decimal("5.0"),
                "cart_discount": Decimal("0.0"),
                "payments": [],  # 0 paid, full due
            },
            # Sale 8 (Today): Fast cash sale
            {
                "receipt_no": "REC-20261104-MAIN-0001",
                "customer": None,
                "cashier_id": DEV_USER_ID,
                "created_at": now_utc - timedelta(hours=2),
                "items": [(v_mojo, Decimal("3.0"), Decimal("0.0")), (v_frooto, Decimal("2.0"), Decimal("0.0"))],
                "tax_rate": Decimal("5.0"),
                "cart_discount": Decimal("0.0"),
                "payments": [("CASH", Decimal("150.0000"), "Tendered 150, change returned")],
            },
            # Sale 9 (Today): bKash sale with gift wrap
            {
                "receipt_no": "REC-20261104-MAIN-0002",
                "customer": None,
                "cashier_id": DEV_USER_ID,
                "created_at": now_utc - timedelta(hours=1),
                "items": [(v_polo_l, Decimal("1.0"), Decimal("0.0")), (v_gift, Decimal("1.0"), Decimal("0.0"))],
                "tax_rate": Decimal("5.0"),
                "cart_discount": Decimal("0.0"),
                "payments": [("BKASH", Decimal("630.0000"), "TRX-BK-77889")],
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

                # Record stock ledger movement
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

            # Payment tenders
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
                notes="Standard completed checkout transaction",
                created_at=s_spec["created_at"],
            )
            session.add(sale_entity)
            session.add_all(sale_items)
            session.add_all(payment_entities)

        await session.flush()

        # 12. Inter-Branch Stock Transfers (Track 5 feature)
        print("Seeding stock transfers between branches...")
        trf_1 = StockTransfer(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            source_branch_id=DEV_BRANCH_ID,
            destination_branch_id=BRANCH_DHAN_ID,
            transfer_no="TRF-20261102-0001",
            status="RECEIVED",
            notes="Replenishment stock shipment to Dhanmondi",
            created_by=DEV_USER_ID,
            sent_at=now_utc - timedelta(days=2),
            received_by=USER_KARIM_ID,
            received_at=now_utc - timedelta(days=1, hours=20),
            created_at=now_utc - timedelta(days=2),
        )
        session.add(trf_1)
        await session.flush()

        ti1_1 = StockTransferItem(
            id=uuid.uuid4(),
            transfer_id=trf_1.id,
            product_variant_id=v_mojo.id,
            quantity=Decimal("30.0000"),
            unit_cost=v_mojo.cost_price,
        )
        ti1_2 = StockTransferItem(
            id=uuid.uuid4(),
            transfer_id=trf_1.id,
            product_variant_id=v_kitkat.id,
            quantity=Decimal("20.0000"),
            unit_cost=v_kitkat.cost_price,
        )
        session.add_all([ti1_1, ti1_2])

        trf_2 = StockTransfer(
            id=uuid.uuid4(),
            business_id=DEV_BUSINESS_ID,
            source_branch_id=DEV_BRANCH_ID,
            destination_branch_id=BRANCH_UTTR_ID,
            transfer_no="TRF-20261104-0002",
            status="IN_TRANSIT",
            notes="Urgent inventory transfer to Uttara Outlet",
            created_by=DEV_USER_ID,
            sent_at=now_utc - timedelta(hours=2),
            received_by=None,
            received_at=None,
            created_at=now_utc - timedelta(hours=2),
        )
        session.add(trf_2)
        await session.flush()

        ti2_1 = StockTransferItem(
            id=uuid.uuid4(),
            transfer_id=trf_2.id,
            product_variant_id=v_frooto.id,
            quantity=Decimal("25.0000"),
            unit_cost=v_frooto.cost_price,
        )
        session.add(ti2_1)

        # Commit all seeded data
        await session.commit()
        print("All comprehensive dummy data committed successfully!")


async def main() -> None:
    print("=" * 70)
    print("RETAIL POS: DATABASE RESET AND COMPREHENSIVE SEEDING")
    print("=" * 70)
    await reset_schema()
    run_migrations()
    await seed_data()
    print("=" * 70)
    print("DATABASE RESET AND SEEDING COMPLETED SUCCESSFULLY!")
    print("=" * 70)


if __name__ == "__main__":
    asyncio.run(main())
