# Product Catalog & Categories Module (Vertical Slice 1)

This document provides a comprehensive technical overview of the Product Catalog and Categories vertical slice implemented across the backend FastAPI service and the Flutter POS client application.

---

## 1. Overview & Architecture

The Catalog slice enables multi-tenant retail businesses to organize their inventory taxonomy into parent/child categories, manage standard products and their primary variants, assign unique SKUs and barcodes, track cost and selling prices, toggle active/inactive states, and search/paginate inventory on the POS terminal.

```
+-----------------------------------------------------------+
|                     Flutter POS Client                    |
|  - CatalogScreen (Tabs: Products, Categories)             |
|  - ProductListView (Search, Filter, Paginated DataTable)   |
|  - ProductFormDialog (Create & Edit validations)          |
|  - CategoryListView (Management & Hierarchical display)   |
|  - CategoryFormDialog (Create & Edit dialog)              |
|  - Riverpod StateNotifiers & FutureProviders               |
|  - ApiClient (Dio with Bearer token & error normalization)|
+-----------------------------------------------------------+
                             | REST JSON
                             v
+-----------------------------------------------------------+
|                     FastAPI Backend                       |
|  - app.api.v1.catalog (Endpoints for Categories & Products)|
|  - CatalogService (Domain rules, duplicate checks)         |
|  - ProductRepository & CategoryRepository                 |
|  - SQLAlchemy 2.0 Async PostgreSQL with multi-tenancy     |
+-----------------------------------------------------------+
```

---

## 2. Backend REST API Endpoints

All catalog endpoints are prefixed with `/api/v1` and require:
- Header: `Authorization: Bearer <JWT_ACCESS_TOKEN>`
- Tenant scoping: Automatically extracted from the authenticated user's `business_id` claim in JWT.
- Permission enforcement: `catalog:read` for querying, `catalog:write` for modifications.

### 2.1 Category Endpoints

| Method | Endpoint | Description | Permission |
|--------|----------|-------------|------------|
| `GET` | `/api/v1/categories?is_active=true` | List all business categories (optional active filter) | `catalog:read` |
| `POST` | `/api/v1/categories` | Create a new category | `catalog:write` |
| `PUT` | `/api/v1/categories/{category_id}` | Update category details (name, code, parent, active) | `catalog:write` |

#### Category Request / Response Sample:
**Request (`POST /api/v1/categories`):**
```json
{
  "name": "Electronics",
  "code": "ELEC",
  "parent_id": null,
  "is_active": true
}
```

**Response (`201 Created`):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "business_id": "110e8400-e29b-41d4-a716-446655440000",
  "name": "Electronics",
  "code": "ELEC",
  "parent_id": null,
  "is_active": true,
  "created_at": "2026-11-03T20:00:00Z",
  "updated_at": "2026-11-03T20:00:00Z"
}
```

---

### 2.2 Product Endpoints

| Method | Endpoint | Description | Permission |
|--------|----------|-------------|------------|
| `GET` | `/api/v1/products?search=&category_id=&is_active=&page=1&limit=20` | Paginated product list with search and filters | `catalog:read` |
| `POST` | `/api/v1/products` | Create product and primary variant atomically | `catalog:write` |
| `GET` | `/api/v1/products/{product_id}` | Fetch a single product by UUID | `catalog:read` |
| `PUT` | `/api/v1/products/{product_id}` | Update product and its primary variant | `catalog:write` |
| `GET` | `/api/v1/products/barcode/{barcode}` | Quick POS barcode scanner lookup | `catalog:read` |

#### Product Request / Response Sample:
**Request (`POST /api/v1/products`):**
```json
{
  "sku": "WM-001",
  "name": "Wireless Ergonomic Mouse",
  "description": "2.4GHz optical wireless mouse",
  "category_id": "550e8400-e29b-41d4-a716-446655440000",
  "product_type": "standard",
  "tax_rate": 5.00,
  "barcode": "8901234567890",
  "cost_price": 12.5000,
  "selling_price": 24.9900,
  "track_stock": true,
  "is_active": true
}
```

**Response (`201 Created`):**
```json
{
  "id": "770e8400-e29b-41d4-a716-446655440000",
  "business_id": "110e8400-e29b-41d4-a716-446655440000",
  "sku": "WM-001",
  "name": "Wireless Ergonomic Mouse",
  "description": "2.4GHz optical wireless mouse",
  "category_id": "550e8400-e29b-41d4-a716-446655440000",
  "category_name": "Electronics",
  "product_type": "standard",
  "tax_rate": 5.0,
  "has_variants": false,
  "is_active": true,
  "primary_variant": {
    "id": "880e8400-e29b-41d4-a716-446655440000",
    "product_id": "770e8400-e29b-41d4-a716-446655440000",
    "sku": "WM-001",
    "name": "Default",
    "barcode": "8901234567890",
    "cost_price": 12.5,
    "selling_price": 24.99,
    "track_stock": true,
    "is_active": true,
    "created_at": "2026-11-03T20:00:00Z",
    "updated_at": "2026-11-03T20:00:00Z"
  },
  "variants": [ ... ],
  "created_at": "2026-11-03T20:00:00Z",
  "updated_at": "2026-11-03T20:00:00Z"
}
```

---

## 3. Error Codes & Validation

All application-specific failures return HTTP 400 or 403 with standard structured error envelopes:
```json
{
  "detail": {
    "error_code": "DUPLICATE_SKU",
    "message": "A product with SKU 'WM-001' already exists in this business"
  }
}
```

Supported error codes:
- `DUPLICATE_SKU`: SKU already exists in this business.
- `DUPLICATE_BARCODE`: Barcode is already assigned to another variant in this business.
- `DUPLICATE_CATEGORY`: Category name already exists in this business.
- `CIRCULAR_HIERARCHY`: A category cannot be its own parent or descendant.
- `PRODUCT_NOT_FOUND`: Specified product ID does not exist or belongs to another business.
- `CATEGORY_NOT_FOUND`: Specified category ID does not exist.
- `PERMISSION_DENIED`: Current user lacks the required permission claim.

---

## 4. Flutter Client Implementation

### 4.1 State Management (Riverpod)
- `categoryListProvider` (`StateNotifierProvider<CategoryListNotifier, AsyncValue<List<CategoryModel>>>`): Manages asynchronous category loading, filtering (active/inactive/all), and updates.
- `productFilterProvider` (`StateNotifierProvider<ProductFilterNotifier, ProductFilterState>`): Manages current search keyword, category filter ID, active status filter, page index, and items limit.
- `paginatedProductsProvider` (`FutureProvider<PaginatedProducts>`): Automatically reactive; re-fetches products whenever any property in `productFilterProvider` changes.
- `productMutationProvider` (`StateNotifierProvider<ProductMutationNotifier, AsyncValue<ProductModel?>>`): Coordinates create and edit operations, invalidating `paginatedProductsProvider` on successful mutation.

### 4.2 Presentation Widgets
- `CatalogScreen`: Tabbed view hosting the Products and Categories interfaces. Integrated as destination index 1 in `ShellScreen`.
- `ProductListView`: Features live search, category dropdown filter, active/inactive segmented buttons, a responsive horizontal/vertical scrolling `DataTable`, status badges, and pagination footer (showing current page, total pages, and total count).
- `ProductFormDialog`: Modal dialog for creating and editing products. Handles client-side validations (SKU, name, positive prices) and displays server errors.
- `CategoryListView`: Card-based list displaying categories, hierarchical codes, parent labels, and status badges.
- `CategoryFormDialog`: Modal dialog for creating and modifying parent/child categories.

---

## 5. Verification Commands

### Backend Verification:
```powershell
cd backend
.\.venv\Scripts\pytest.exe tests/test_catalog.py -v
.\.venv\Scripts\ruff.exe check app tests alembic
.\.venv\Scripts\mypy.exe --config-file pyproject.toml app tests
```

### Flutter Client Verification:
```powershell
cd pos_system_application
flutter analyze
flutter test
```
