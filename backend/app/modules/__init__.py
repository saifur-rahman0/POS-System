"""Domain modules for POS backend."""

from app.modules.business.models import Branch, Business
from app.modules.catalog.models import (
    Brand,
    Category,
    ImeiDevice,
    Product,
    ProductVariant,
)
from app.modules.expenses.models import CashTransaction, Expense
from app.modules.identity.models import (
    Device,
    Membership,
    MembershipRole,
    Permission,
    Role,
    RolePermission,
    User,
)
from app.modules.inventory.models import (
    StockBalance,
    StockCount,
    StockCountLine,
    StockMovement,
)
from app.modules.platform.models import (
    AuditLog,
    BackupRecord,
    IdempotencyRecord,
    LicenseRecord,
    SyncOutbox,
)
from app.modules.purchasing.models import (
    Purchase,
    PurchaseItem,
    PurchasePayment,
    Supplier,
)
from app.modules.returns.models import Return, ReturnItem
from app.modules.sales.models import (
    Customer,
    PaymentTender,
    Sale,
    SaleItem,
)

__all__ = [
    # Business
    "Business",
    "Branch",
    # Identity
    "User",
    "Membership",
    "Role",
    "Permission",
    "RolePermission",
    "MembershipRole",
    "Device",
    # Catalog
    "Category",
    "Brand",
    "Product",
    "ProductVariant",
    "ImeiDevice",
    # Inventory
    "StockMovement",
    "StockBalance",
    "StockCount",
    "StockCountLine",
    # Purchasing
    "Supplier",
    "Purchase",
    "PurchaseItem",
    "PurchasePayment",
    # Sales
    "Customer",
    "Sale",
    "SaleItem",
    "PaymentTender",
    # Returns
    "Return",
    "ReturnItem",
    # Expenses
    "Expense",
    "CashTransaction",
    # Platform
    "AuditLog",
    "IdempotencyRecord",
    "LicenseRecord",
    "BackupRecord",
    "SyncOutbox",
]
