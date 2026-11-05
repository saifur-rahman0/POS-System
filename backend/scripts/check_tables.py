import asyncio
import sys

sys.path.insert(0, ".")
from sqlalchemy import text

from app.database import get_session_maker


async def main():
    session = get_session_maker()()
    res = await session.execute(text("SELECT table_name FROM information_schema.tables WHERE table_schema='public'"))
    tables = sorted([r[0] for r in res.fetchall()])
    print("Tables in DB:", tables)
    await session.close()

if __name__ == "__main__":
    asyncio.run(main())

