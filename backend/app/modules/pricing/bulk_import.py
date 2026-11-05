"""Bulk product and pricing CSV / Excel import engine."""

import csv
import io
import uuid
from decimal import Decimal, InvalidOperation

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.catalog.models import Category, Product, ProductVariant
from app.modules.pricing.schemas import BulkImportError, BulkImportResult


class BulkImportProcessor:
    """Parser and batch transactional importer for catalog variants and prices."""

    EXPECTED_HEADERS = {
        "product_sku",
        "product_name",
        "variant_name",
        "cost_price",
        "selling_price",
    }

    async def process_csv(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        file_content: bytes,
    ) -> BulkImportResult:
        """Parse and ingest a CSV file containing product variants and pricing."""
        try:
            text_data = file_content.decode("utf-8-sig")
        except UnicodeDecodeError:
            text_data = file_content.decode("latin-1")

        reader = csv.DictReader(io.StringIO(text_data))
        if not reader.fieldnames:
            return BulkImportResult(
                total_rows=0,
                created_count=0,
                updated_count=0,
                error_count=1,
                errors=[BulkImportError(row=0, message="Empty CSV file or missing headers")],
            )

        # Normalize headers
        normalized_headers = {h.strip().lower() for h in reader.fieldnames if h}
        missing_headers = self.EXPECTED_HEADERS - normalized_headers
        if missing_headers:
            return BulkImportResult(
                total_rows=0,
                created_count=0,
                updated_count=0,
                error_count=1,
                errors=[
                    BulkImportError(
                        row=0,
                        message=f"Missing required columns: {', '.join(sorted(missing_headers))}",
                    )
                ],
            )

        total_rows = 0
        created_count = 0
        updated_count = 0
        errors: list[BulkImportError] = []

        # Category cache for this import session
        categories_cache: dict[str, uuid.UUID] = {}

        for row_idx, raw_row in enumerate(reader, start=2):
            total_rows += 1
            row = {k.strip().lower(): v.strip() for k, v in raw_row.items() if k and v is not None}

            sku = row.get("product_sku", "")
            product_name = row.get("product_name", "")
            variant_name = row.get("variant_name", "")
            barcode = row.get("barcode") or None
            category_name = row.get("category_name", "")

            if not sku:
                errors.append(BulkImportError(row=row_idx, field="product_sku", message="product_sku is required"))
                continue
            if not product_name:
                errors.append(BulkImportError(row=row_idx, field="product_name", message="product_name is required"))
                continue
            if not variant_name:
                errors.append(BulkImportError(row=row_idx, field="variant_name", message="variant_name is required"))
                continue

            try:
                cost_price = Decimal(row.get("cost_price", "0"))
                if cost_price < 0:
                    raise ValueError("Cost price cannot be negative")
            except (InvalidOperation, ValueError) as e:
                errors.append(BulkImportError(row=row_idx, field="cost_price", message=str(e)))
                continue

            try:
                selling_price = Decimal(row.get("selling_price", "0"))
                if selling_price < 0:
                    raise ValueError("Selling price cannot be negative")
            except (InvalidOperation, ValueError) as e:
                errors.append(BulkImportError(row=row_idx, field="selling_price", message=str(e)))
                continue

            track_stock_val = row.get("track_stock", "true").lower() in ("true", "1", "yes", "y")

            # Handle Category
            category_id: uuid.UUID | None = None
            if category_name:
                cat_lower = category_name.lower()
                if cat_lower in categories_cache:
                    category_id = categories_cache[cat_lower]
                else:
                    cat_stmt = select(Category).where(
                        Category.business_id == business_id,
                        Category.parent_id == None,  # noqa: E711
                        Category.name.ilike(category_name),
                    )
                    cat_res = await session.execute(cat_stmt)
                    cat_obj = cat_res.scalar_one_or_none()
                    if not cat_obj:
                        cat_obj = Category(
                            business_id=business_id,
                            name=category_name,
                            is_active=True,
                        )
                        session.add(cat_obj)
                        await session.flush()
                        await session.refresh(cat_obj)
                    categories_cache[cat_lower] = cat_obj.id
                    category_id = cat_obj.id

            # Find or Create Product
            prod_stmt = select(Product).where(
                Product.business_id == business_id,
                Product.sku == sku,
            )
            prod_res = await session.execute(prod_stmt)
            product = prod_res.scalar_one_or_none()

            if not product:
                product = Product(
                    business_id=business_id,
                    sku=sku,
                    name=product_name,
                    category_id=category_id,
                    product_type="STANDARD",
                    is_active=True,
                )
                session.add(product)
                await session.flush()
                await session.refresh(product)

            # Find or Create Variant
            var_stmt = select(ProductVariant).where(
                ProductVariant.business_id == business_id,
                ProductVariant.product_id == product.id,
                ProductVariant.name == variant_name,
            )
            var_res = await session.execute(var_stmt)
            variant = var_res.scalar_one_or_none()

            if variant:
                # Update existing
                variant.cost_price = cost_price
                variant.selling_price = selling_price
                variant.track_stock = track_stock_val
                if barcode:
                    variant.barcode = barcode
                updated_count += 1
            else:
                # Create new
                new_variant = ProductVariant(
                    business_id=business_id,
                    product_id=product.id,
                    name=variant_name,
                    barcode=barcode,
                    cost_price=cost_price,
                    selling_price=selling_price,
                    track_stock=track_stock_val,
                    is_active=True,
                )
                session.add(new_variant)
                created_count += 1

            await session.flush()

        return BulkImportResult(
            total_rows=total_rows,
            created_count=created_count,
            updated_count=updated_count,
            error_count=len(errors),
            errors=errors,
        )

