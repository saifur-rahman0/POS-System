import asyncio
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from sqlalchemy import text

from app.database import get_session_maker


async def main():
    session = get_session_maker()()
    res = await session.execute(text("SELECT table_name FROM information_schema.tables WHERE table_schema='public'"))
    tables = sorted([r[0] for r in res.fetchall()])
    print(f"Total tables: {len(tables)}")
    key_tables = [
        'businesses', 'branches', 'categories', 'products', 'product_variants',
        'customers', 'sales', 'financial_accounts', 'account_transfers',
        'expense_categories', 'expenses', 'recurring_expenses',
        'inventory_batches', 'damaged_stock_records', 'stock_reservations',
        'customer_groups', 'price_lists', 'promotions', 'membership_tiers', 'gift_cards'
    ]
    for t in key_tables:
        if t in tables:
            cnt = (await session.execute(text(f"SELECT COUNT(*) FROM {t}"))).scalar()
            print(f"  {t}: {cnt}")
    await session.close()

if __name__ == "__main__":
    asyncio.run(main())

