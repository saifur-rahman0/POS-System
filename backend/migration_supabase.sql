BEGIN;

CREATE TABLE alembic_version (
    version_num VARCHAR(32) NOT NULL, 
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

-- Running upgrade  -> ad56b6eabc03

CREATE TABLE backup_records (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    backup_type VARCHAR(32) NOT NULL, 
    file_name VARCHAR(255) NOT NULL, 
    size_bytes BIGINT NOT NULL, 
    checksum VARCHAR(64) NOT NULL, 
    status VARCHAR(32) NOT NULL, 
    error_message TEXT, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id)
);

CREATE TABLE businesses (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    name VARCHAR(255) NOT NULL, 
    legal_name VARCHAR(255), 
    timezone VARCHAR(64) DEFAULT 'Asia/Dhaka' NOT NULL, 
    currency VARCHAR(10) DEFAULT 'BDT' NOT NULL, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id)
);

CREATE TABLE permissions (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    code VARCHAR(100) NOT NULL, 
    description VARCHAR(255) NOT NULL, 
    PRIMARY KEY (id)
);

CREATE UNIQUE INDEX ix_permissions_code ON permissions (code);

CREATE TABLE users (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    username VARCHAR(100) NOT NULL, 
    email VARCHAR(255), 
    password_hash VARCHAR(255) NOT NULL, 
    display_name VARCHAR(255) NOT NULL, 
    phone VARCHAR(50), 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id)
);

CREATE UNIQUE INDEX ix_users_email ON users (email);

CREATE UNIQUE INDEX ix_users_username ON users (username);

CREATE TABLE branches (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    name VARCHAR(255) NOT NULL, 
    code VARCHAR(50), 
    address TEXT, 
    phone VARCHAR(50), 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    CONSTRAINT uq_branches_business_name UNIQUE (business_id, name)
);

CREATE INDEX ix_branches_business_id ON branches (business_id);

CREATE TABLE brands (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    name VARCHAR(255) NOT NULL, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    CONSTRAINT uq_brands_business_name UNIQUE (business_id, name)
);

CREATE INDEX ix_brands_business_id ON brands (business_id);

CREATE TABLE categories (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    parent_id UUID, 
    name VARCHAR(255) NOT NULL, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(parent_id) REFERENCES categories (id) ON DELETE SET NULL, 
    CONSTRAINT uq_categories_business_parent_name UNIQUE (business_id, parent_id, name)
);

CREATE INDEX ix_categories_business_id ON categories (business_id);

CREATE INDEX ix_categories_parent_id ON categories (parent_id);

CREATE TABLE customers (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    name VARCHAR(255) NOT NULL, 
    phone VARCHAR(50), 
    email VARCHAR(255), 
    address TEXT, 
    credit_limit NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_customer_credit_limit_non_negative CHECK (credit_limit >= 0), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT
);

CREATE INDEX ix_customers_business_id ON customers (business_id);

CREATE INDEX ix_customers_phone ON customers (phone);

CREATE UNIQUE INDEX uq_customers_business_phone ON customers (business_id, phone) WHERE phone IS NOT NULL;

CREATE TABLE idempotency_records (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    endpoint VARCHAR(255) NOT NULL, 
    idempotency_key VARCHAR(255) NOT NULL, 
    request_hash VARCHAR(64) NOT NULL, 
    response_json JSONB NOT NULL, 
    status_code INTEGER NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    CONSTRAINT uq_idempotency_business_endpoint_key UNIQUE (business_id, endpoint, idempotency_key)
);

CREATE INDEX ix_idempotency_created_at ON idempotency_records (created_at);

CREATE INDEX ix_idempotency_records_business_id ON idempotency_records (business_id);

CREATE TABLE license_records (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    license_key_id VARCHAR(100) NOT NULL, 
    license_payload TEXT NOT NULL, 
    signature TEXT NOT NULL, 
    device_limit INTEGER DEFAULT 1 NOT NULL, 
    activated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    expires_at TIMESTAMP WITHOUT TIME ZONE, 
    status VARCHAR(32) DEFAULT 'ACTIVE' NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT
);

CREATE INDEX ix_license_records_business_id ON license_records (business_id);

CREATE TABLE memberships (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    user_id UUID NOT NULL, 
    status VARCHAR(32) DEFAULT 'ACTIVE' NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE RESTRICT, 
    CONSTRAINT uq_memberships_business_user UNIQUE (business_id, user_id)
);

CREATE INDEX ix_memberships_business_id ON memberships (business_id);

CREATE INDEX ix_memberships_user_id ON memberships (user_id);

CREATE TABLE roles (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID, 
    name VARCHAR(100) NOT NULL, 
    description TEXT, 
    PRIMARY KEY (id), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    CONSTRAINT uq_roles_business_name UNIQUE (business_id, name)
);

CREATE INDEX ix_roles_business_id ON roles (business_id);

CREATE TABLE suppliers (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    name VARCHAR(255) NOT NULL, 
    contact_person VARCHAR(255), 
    phone VARCHAR(50), 
    email VARCHAR(255), 
    address TEXT, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    CONSTRAINT uq_suppliers_business_name UNIQUE (business_id, name)
);

CREATE INDEX ix_suppliers_business_id ON suppliers (business_id);

CREATE TABLE sync_outbox (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    event_id UUID NOT NULL, 
    aggregate_type VARCHAR(100) NOT NULL, 
    aggregate_id UUID NOT NULL, 
    event_type VARCHAR(100) NOT NULL, 
    payload_json JSONB NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    synced_at TIMESTAMP WITHOUT TIME ZONE, 
    PRIMARY KEY (id), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT
);

CREATE INDEX ix_sync_outbox_aggregate_id ON sync_outbox (aggregate_id);

CREATE INDEX ix_sync_outbox_business_id ON sync_outbox (business_id);

CREATE INDEX ix_sync_outbox_created_at ON sync_outbox (created_at);

CREATE UNIQUE INDEX ix_sync_outbox_event_id ON sync_outbox (event_id);

CREATE INDEX ix_sync_outbox_synced_at ON sync_outbox (synced_at);

CREATE TABLE audit_logs (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID, 
    actor_user_id UUID NOT NULL, 
    action VARCHAR(100) NOT NULL, 
    entity_type VARCHAR(100) NOT NULL, 
    entity_id UUID NOT NULL, 
    before_json JSONB, 
    after_json JSONB, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(actor_user_id) REFERENCES users (id) ON DELETE RESTRICT, 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT
);

CREATE INDEX ix_audit_logs_actor_user_id ON audit_logs (actor_user_id);

CREATE INDEX ix_audit_logs_branch_id ON audit_logs (branch_id);

CREATE INDEX ix_audit_logs_business_date ON audit_logs (business_id, created_at DESC);

CREATE INDEX ix_audit_logs_business_entity ON audit_logs (business_id, entity_type, entity_id);

CREATE INDEX ix_audit_logs_business_id ON audit_logs (business_id);

CREATE INDEX ix_audit_logs_created_at ON audit_logs (created_at);

CREATE INDEX ix_audit_logs_entity_id ON audit_logs (entity_id);

CREATE TABLE cash_transactions (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    account_id VARCHAR(100) NOT NULL, 
    direction VARCHAR(10) NOT NULL, 
    amount NUMERIC(19, 4) NOT NULL, 
    reference_type VARCHAR(50) NOT NULL, 
    reference_id UUID NOT NULL, 
    note TEXT, 
    created_by UUID NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_cash_txn_amount_positive CHECK (amount > 0), 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(created_by) REFERENCES users (id) ON DELETE RESTRICT
);

CREATE INDEX ix_cash_transactions_branch_id ON cash_transactions (branch_id);

CREATE INDEX ix_cash_transactions_business_id ON cash_transactions (business_id);

CREATE INDEX ix_cash_transactions_created_by ON cash_transactions (created_by);

CREATE INDEX ix_cash_transactions_reference_id ON cash_transactions (reference_id);

CREATE TABLE devices (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    label VARCHAR(100) NOT NULL, 
    device_fingerprint VARCHAR(255) NOT NULL, 
    status VARCHAR(32) DEFAULT 'ACTIVE' NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    CONSTRAINT uq_devices_business_fingerprint UNIQUE (business_id, device_fingerprint)
);

CREATE INDEX ix_devices_branch_id ON devices (branch_id);

CREATE INDEX ix_devices_business_id ON devices (business_id);

CREATE TABLE expenses (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    category VARCHAR(100) NOT NULL, 
    amount NUMERIC(19, 4) NOT NULL, 
    note TEXT, 
    created_by UUID NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_expense_amount_positive CHECK (amount > 0), 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(created_by) REFERENCES users (id) ON DELETE RESTRICT
);

CREATE INDEX ix_expenses_branch_id ON expenses (branch_id);

CREATE INDEX ix_expenses_business_id ON expenses (business_id);

CREATE INDEX ix_expenses_created_by ON expenses (created_by);

CREATE TABLE membership_roles (
    membership_id UUID NOT NULL, 
    role_id UUID NOT NULL, 
    PRIMARY KEY (membership_id, role_id), 
    FOREIGN KEY(membership_id) REFERENCES memberships (id) ON DELETE CASCADE, 
    FOREIGN KEY(role_id) REFERENCES roles (id) ON DELETE CASCADE
);

CREATE TABLE products (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    sku VARCHAR(100) NOT NULL, 
    name VARCHAR(255) NOT NULL, 
    category_id UUID, 
    brand_id UUID, 
    product_type VARCHAR(32) DEFAULT 'STANDARD' NOT NULL, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(brand_id) REFERENCES brands (id) ON DELETE SET NULL, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(category_id) REFERENCES categories (id) ON DELETE SET NULL, 
    CONSTRAINT uq_products_business_sku UNIQUE (business_id, sku)
);

CREATE INDEX ix_products_brand_id ON products (brand_id);

CREATE INDEX ix_products_business_id ON products (business_id);

CREATE INDEX ix_products_category_id ON products (category_id);

CREATE INDEX ix_products_sku ON products (sku);

CREATE TABLE purchases (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    supplier_id UUID NOT NULL, 
    reference_no VARCHAR(100) NOT NULL, 
    status VARCHAR(32) DEFAULT 'ORDERED' NOT NULL, 
    subtotal NUMERIC(19, 4) NOT NULL, 
    discount NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    total NUMERIC(19, 4) NOT NULL, 
    paid_total NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    notes TEXT, 
    created_by UUID NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_purchase_discount_non_negative CHECK (discount >= 0), 
    CONSTRAINT chk_purchase_paid_total_non_negative CHECK (paid_total >= 0), 
    CONSTRAINT chk_purchase_subtotal_non_negative CHECK (subtotal >= 0), 
    CONSTRAINT chk_purchase_total_non_negative CHECK (total >= 0), 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(created_by) REFERENCES users (id) ON DELETE RESTRICT, 
    FOREIGN KEY(supplier_id) REFERENCES suppliers (id) ON DELETE RESTRICT, 
    CONSTRAINT uq_purchases_business_reference_no UNIQUE (business_id, reference_no)
);

CREATE INDEX ix_purchases_branch_id ON purchases (branch_id);

CREATE INDEX ix_purchases_business_id ON purchases (business_id);

CREATE INDEX ix_purchases_created_at ON purchases (created_at);

CREATE INDEX ix_purchases_created_by ON purchases (created_by);

CREATE INDEX ix_purchases_supplier_id ON purchases (supplier_id);

CREATE TABLE role_permissions (
    role_id UUID NOT NULL, 
    permission_id UUID NOT NULL, 
    PRIMARY KEY (role_id, permission_id), 
    FOREIGN KEY(permission_id) REFERENCES permissions (id) ON DELETE CASCADE, 
    FOREIGN KEY(role_id) REFERENCES roles (id) ON DELETE CASCADE
);

CREATE TABLE sales (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    receipt_no VARCHAR(100) NOT NULL, 
    customer_id UUID, 
    cashier_id UUID NOT NULL, 
    status VARCHAR(32) DEFAULT 'COMPLETED' NOT NULL, 
    subtotal NUMERIC(19, 4) NOT NULL, 
    discount_total NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    tax_total NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    grand_total NUMERIC(19, 4) NOT NULL, 
    paid_total NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    due_total NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    idempotency_key VARCHAR(255) NOT NULL, 
    notes TEXT, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_sale_discount_non_negative CHECK (discount_total >= 0), 
    CONSTRAINT chk_sale_due_total_non_negative CHECK (due_total >= 0), 
    CONSTRAINT chk_sale_grand_total_non_negative CHECK (grand_total >= 0), 
    CONSTRAINT chk_sale_paid_total_non_negative CHECK (paid_total >= 0), 
    CONSTRAINT chk_sale_subtotal_non_negative CHECK (subtotal >= 0), 
    CONSTRAINT chk_sale_tax_non_negative CHECK (tax_total >= 0), 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(cashier_id) REFERENCES users (id) ON DELETE RESTRICT, 
    FOREIGN KEY(customer_id) REFERENCES customers (id) ON DELETE RESTRICT, 
    CONSTRAINT uq_sales_business_idempotency_key UNIQUE (business_id, idempotency_key), 
    CONSTRAINT uq_sales_business_receipt_no UNIQUE (business_id, receipt_no)
);

CREATE INDEX ix_sales_branch_id ON sales (branch_id);

CREATE INDEX ix_sales_business_branch_date ON sales (business_id, branch_id, created_at DESC);

CREATE INDEX ix_sales_business_id ON sales (business_id);

CREATE INDEX ix_sales_cashier_id ON sales (cashier_id);

CREATE INDEX ix_sales_created_at ON sales (created_at);

CREATE INDEX ix_sales_customer_id ON sales (customer_id);

CREATE INDEX ix_sales_receipt_no ON sales (receipt_no);

CREATE TABLE stock_counts (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    status VARCHAR(32) DEFAULT 'DRAFT' NOT NULL, 
    created_by UUID NOT NULL, 
    approved_by UUID, 
    notes TEXT, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    completed_at TIMESTAMP WITHOUT TIME ZONE, 
    PRIMARY KEY (id), 
    FOREIGN KEY(approved_by) REFERENCES users (id) ON DELETE RESTRICT, 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(created_by) REFERENCES users (id) ON DELETE RESTRICT
);

CREATE INDEX ix_stock_counts_approved_by ON stock_counts (approved_by);

CREATE INDEX ix_stock_counts_branch_id ON stock_counts (branch_id);

CREATE INDEX ix_stock_counts_business_id ON stock_counts (business_id);

CREATE INDEX ix_stock_counts_created_by ON stock_counts (created_by);

CREATE TABLE payment_tenders (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    sale_id UUID NOT NULL, 
    method VARCHAR(32) NOT NULL, 
    amount NUMERIC(19, 4) NOT NULL, 
    reference VARCHAR(100), 
    status VARCHAR(32) DEFAULT 'CONFIRMED' NOT NULL, 
    received_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_payment_tender_amount_positive CHECK (amount > 0), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(sale_id) REFERENCES sales (id) ON DELETE RESTRICT
);

CREATE INDEX ix_payment_tenders_business_id ON payment_tenders (business_id);

CREATE INDEX ix_payment_tenders_sale_id ON payment_tenders (sale_id);

CREATE TABLE product_variants (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    product_id UUID NOT NULL, 
    business_id UUID NOT NULL, 
    name VARCHAR(255) NOT NULL, 
    barcode VARCHAR(100), 
    attributes_json JSONB DEFAULT '{}'::jsonb NOT NULL, 
    selling_price NUMERIC(19, 4) NOT NULL, 
    cost_price NUMERIC(19, 4) NOT NULL, 
    track_stock BOOLEAN DEFAULT true NOT NULL, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_variant_cost_price_non_negative CHECK (cost_price >= 0), 
    CONSTRAINT chk_variant_selling_price_non_negative CHECK (selling_price >= 0), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(product_id) REFERENCES products (id) ON DELETE RESTRICT
);

CREATE INDEX ix_product_variants_barcode ON product_variants (barcode);

CREATE INDEX ix_product_variants_business_id ON product_variants (business_id);

CREATE INDEX ix_product_variants_product_id ON product_variants (product_id);

CREATE UNIQUE INDEX uq_variants_business_barcode ON product_variants (business_id, barcode) WHERE barcode IS NOT NULL;

CREATE TABLE purchase_payments (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    purchase_id UUID NOT NULL, 
    business_id UUID NOT NULL, 
    amount NUMERIC(19, 4) NOT NULL, 
    method VARCHAR(32) NOT NULL, 
    reference VARCHAR(100), 
    paid_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_purchase_payment_amount_positive CHECK (amount > 0), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(purchase_id) REFERENCES purchases (id) ON DELETE RESTRICT
);

CREATE INDEX ix_purchase_payments_business_id ON purchase_payments (business_id);

CREATE INDEX ix_purchase_payments_purchase_id ON purchase_payments (purchase_id);

CREATE TABLE returns (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    original_sale_id UUID NOT NULL, 
    return_no VARCHAR(100) NOT NULL, 
    status VARCHAR(32) DEFAULT 'COMPLETED' NOT NULL, 
    refund_total NUMERIC(19, 4) NOT NULL, 
    reason TEXT, 
    created_by UUID NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_return_refund_total_non_negative CHECK (refund_total >= 0), 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(created_by) REFERENCES users (id) ON DELETE RESTRICT, 
    FOREIGN KEY(original_sale_id) REFERENCES sales (id) ON DELETE RESTRICT, 
    CONSTRAINT uq_returns_business_return_no UNIQUE (business_id, return_no)
);

CREATE INDEX ix_returns_branch_id ON returns (branch_id);

CREATE INDEX ix_returns_business_id ON returns (business_id);

CREATE INDEX ix_returns_created_by ON returns (created_by);

CREATE INDEX ix_returns_original_sale_id ON returns (original_sale_id);

CREATE INDEX ix_returns_return_no ON returns (return_no);

CREATE TABLE imei_devices (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    product_variant_id UUID NOT NULL, 
    imei1 VARCHAR(30) NOT NULL, 
    imei2 VARCHAR(30), 
    serial_number VARCHAR(100), 
    purchase_id UUID, 
    status VARCHAR(32) DEFAULT 'IN_STOCK' NOT NULL, 
    sold_sale_item_id UUID, 
    warranty_end DATE, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(product_variant_id) REFERENCES product_variants (id) ON DELETE RESTRICT, 
    FOREIGN KEY(purchase_id) REFERENCES purchases (id) ON DELETE RESTRICT, 
    CONSTRAINT uq_imei_devices_business_imei1 UNIQUE (business_id, imei1)
);

CREATE INDEX ix_imei_devices_branch_id ON imei_devices (branch_id);

CREATE INDEX ix_imei_devices_business_id ON imei_devices (business_id);

CREATE INDEX ix_imei_devices_imei1 ON imei_devices (imei1);

CREATE INDEX ix_imei_devices_imei2 ON imei_devices (imei2);

CREATE INDEX ix_imei_devices_product_variant_id ON imei_devices (product_variant_id);

CREATE INDEX ix_imei_devices_purchase_id ON imei_devices (purchase_id);

CREATE INDEX ix_imei_devices_serial_number ON imei_devices (serial_number);

CREATE INDEX ix_imei_devices_sold_sale_item_id ON imei_devices (sold_sale_item_id);

CREATE UNIQUE INDEX uq_imei_devices_business_imei2 ON imei_devices (business_id, imei2) WHERE imei2 IS NOT NULL;

CREATE UNIQUE INDEX uq_imei_devices_business_serial ON imei_devices (business_id, serial_number) WHERE serial_number IS NOT NULL;

CREATE TABLE purchase_items (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    purchase_id UUID NOT NULL, 
    product_variant_id UUID NOT NULL, 
    quantity NUMERIC(12, 4) NOT NULL, 
    unit_cost NUMERIC(19, 4) NOT NULL, 
    line_total NUMERIC(19, 4) NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_purchase_item_total_non_negative CHECK (line_total >= 0), 
    CONSTRAINT chk_purchase_item_qty_positive CHECK (quantity > 0), 
    CONSTRAINT chk_purchase_item_cost_non_negative CHECK (unit_cost >= 0), 
    FOREIGN KEY(product_variant_id) REFERENCES product_variants (id) ON DELETE RESTRICT, 
    FOREIGN KEY(purchase_id) REFERENCES purchases (id) ON DELETE RESTRICT
);

CREATE INDEX ix_purchase_items_product_variant_id ON purchase_items (product_variant_id);

CREATE INDEX ix_purchase_items_purchase_id ON purchase_items (purchase_id);

CREATE TABLE stock_balances (
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    product_variant_id UUID NOT NULL, 
    quantity_on_hand NUMERIC(12, 4) DEFAULT 0.0000 NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (business_id, branch_id, product_variant_id), 
    CONSTRAINT chk_stock_balance_non_negative CHECK (quantity_on_hand >= 0), 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(product_variant_id) REFERENCES product_variants (id) ON DELETE RESTRICT
);

CREATE INDEX ix_stock_balances_branch_qty ON stock_balances (business_id, branch_id, quantity_on_hand);

CREATE TABLE stock_count_lines (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    stock_count_id UUID NOT NULL, 
    product_variant_id UUID NOT NULL, 
    expected_qty NUMERIC(12, 4) NOT NULL, 
    counted_qty NUMERIC(12, 4) NOT NULL, 
    discrepancy_reason TEXT, 
    PRIMARY KEY (id), 
    FOREIGN KEY(product_variant_id) REFERENCES product_variants (id) ON DELETE RESTRICT, 
    FOREIGN KEY(stock_count_id) REFERENCES stock_counts (id) ON DELETE CASCADE
);

CREATE INDEX ix_stock_count_lines_product_variant_id ON stock_count_lines (product_variant_id);

CREATE INDEX ix_stock_count_lines_stock_count_id ON stock_count_lines (stock_count_id);

CREATE TABLE sale_items (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    sale_id UUID NOT NULL, 
    product_variant_id UUID NOT NULL, 
    imei_device_id UUID, 
    quantity NUMERIC(12, 4) NOT NULL, 
    unit_price NUMERIC(19, 4) NOT NULL, 
    unit_cost_snapshot NUMERIC(19, 4) NOT NULL, 
    discount NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    line_total NUMERIC(19, 4) NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_sale_item_discount_non_negative CHECK (discount >= 0), 
    CONSTRAINT chk_sale_item_total_non_negative CHECK (line_total >= 0), 
    CONSTRAINT chk_sale_item_qty_positive CHECK (quantity > 0), 
    CONSTRAINT chk_sale_item_cost_snapshot_non_negative CHECK (unit_cost_snapshot >= 0), 
    CONSTRAINT chk_sale_item_price_non_negative CHECK (unit_price >= 0), 
    FOREIGN KEY(imei_device_id) REFERENCES imei_devices (id) ON DELETE RESTRICT, 
    FOREIGN KEY(product_variant_id) REFERENCES product_variants (id) ON DELETE RESTRICT, 
    FOREIGN KEY(sale_id) REFERENCES sales (id) ON DELETE RESTRICT
);

CREATE INDEX ix_sale_items_imei_device_id ON sale_items (imei_device_id);

CREATE INDEX ix_sale_items_product_variant_id ON sale_items (product_variant_id);

CREATE INDEX ix_sale_items_sale_id ON sale_items (sale_id);

CREATE TABLE stock_movements (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    product_variant_id UUID NOT NULL, 
    imei_device_id UUID, 
    movement_type VARCHAR(32) NOT NULL, 
    quantity_delta NUMERIC(12, 4) NOT NULL, 
    unit_cost NUMERIC(19, 4) NOT NULL, 
    reference_type VARCHAR(50) NOT NULL, 
    reference_id UUID NOT NULL, 
    created_by UUID NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_stock_movement_cost_non_negative CHECK (unit_cost >= 0), 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(created_by) REFERENCES users (id) ON DELETE RESTRICT, 
    FOREIGN KEY(imei_device_id) REFERENCES imei_devices (id) ON DELETE RESTRICT, 
    FOREIGN KEY(product_variant_id) REFERENCES product_variants (id) ON DELETE RESTRICT
);

CREATE INDEX ix_stock_movements_branch_id ON stock_movements (branch_id);

CREATE INDEX ix_stock_movements_business_branch_date ON stock_movements (business_id, branch_id, created_at DESC);

CREATE INDEX ix_stock_movements_business_id ON stock_movements (business_id);

CREATE INDEX ix_stock_movements_business_variant ON stock_movements (business_id, product_variant_id);

CREATE INDEX ix_stock_movements_created_at ON stock_movements (created_at);

CREATE INDEX ix_stock_movements_created_by ON stock_movements (created_by);

CREATE INDEX ix_stock_movements_imei_device_id ON stock_movements (imei_device_id);

CREATE INDEX ix_stock_movements_product_variant_id ON stock_movements (product_variant_id);

CREATE INDEX ix_stock_movements_reference_id ON stock_movements (reference_id);

CREATE TABLE return_items (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    return_id UUID NOT NULL, 
    original_sale_item_id UUID NOT NULL, 
    product_variant_id UUID NOT NULL, 
    quantity NUMERIC(12, 4) NOT NULL, 
    refund_amount NUMERIC(19, 4) NOT NULL, 
    restock_status VARCHAR(32) DEFAULT 'RESTOCKED' NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_return_item_qty_positive CHECK (quantity > 0), 
    CONSTRAINT chk_return_item_refund_non_negative CHECK (refund_amount >= 0), 
    FOREIGN KEY(original_sale_item_id) REFERENCES sale_items (id) ON DELETE RESTRICT, 
    FOREIGN KEY(product_variant_id) REFERENCES product_variants (id) ON DELETE RESTRICT, 
    FOREIGN KEY(return_id) REFERENCES returns (id) ON DELETE RESTRICT
);

CREATE INDEX ix_return_items_original_sale_item_id ON return_items (original_sale_item_id);

CREATE INDEX ix_return_items_product_variant_id ON return_items (product_variant_id);

CREATE INDEX ix_return_items_return_id ON return_items (return_id);

INSERT INTO alembic_version (version_num) VALUES ('ad56b6eabc03') RETURNING alembic_version.version_num;

-- Running upgrade ad56b6eabc03 -> b29d10e5f2a1

CREATE TABLE register_shifts (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    user_id UUID NOT NULL, 
    device_id UUID, 
    status VARCHAR(32) DEFAULT 'OPEN' NOT NULL, 
    opened_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    closed_at TIMESTAMP WITHOUT TIME ZONE, 
    opening_cash NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    closing_cash_counted NUMERIC(19, 4), 
    closing_cash_expected NUMERIC(19, 4), 
    cash_difference NUMERIC(19, 4), 
    opening_notes TEXT, 
    closing_notes TEXT, 
    denominations_json JSONB DEFAULT '{}'::jsonb NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_shift_opening_cash_non_negative CHECK (opening_cash >= 0), 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(device_id) REFERENCES devices (id) ON DELETE RESTRICT, 
    FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE RESTRICT
);

CREATE INDEX ix_shifts_business_branch_status ON register_shifts (business_id, branch_id, status);

CREATE INDEX ix_shifts_user_status ON register_shifts (user_id, status);

CREATE INDEX ix_shifts_business_branch_date ON register_shifts (business_id, branch_id, opened_at DESC);

CREATE INDEX ix_register_shifts_business_id ON register_shifts (business_id);

CREATE INDEX ix_register_shifts_branch_id ON register_shifts (branch_id);

CREATE INDEX ix_register_shifts_user_id ON register_shifts (user_id);

CREATE INDEX ix_register_shifts_device_id ON register_shifts (device_id);

CREATE INDEX ix_register_shifts_opened_at ON register_shifts (opened_at);

UPDATE alembic_version SET version_num='b29d10e5f2a1' WHERE alembic_version.version_num = 'ad56b6eabc03';

-- Running upgrade b29d10e5f2a1 -> 254c6db01cfc

CREATE TABLE stock_transfers (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    transfer_no VARCHAR(50) NOT NULL, 
    source_branch_id UUID NOT NULL, 
    destination_branch_id UUID NOT NULL, 
    status VARCHAR(32) DEFAULT 'DRAFT' NOT NULL, 
    created_by UUID NOT NULL, 
    received_by UUID, 
    notes TEXT, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    sent_at TIMESTAMP WITHOUT TIME ZONE, 
    received_at TIMESTAMP WITHOUT TIME ZONE, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_stock_transfer_distinct_branches CHECK (source_branch_id != destination_branch_id), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(created_by) REFERENCES users (id) ON DELETE RESTRICT, 
    FOREIGN KEY(destination_branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(received_by) REFERENCES users (id) ON DELETE RESTRICT, 
    FOREIGN KEY(source_branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    CONSTRAINT uq_stock_transfers_business_no UNIQUE (business_id, transfer_no)
);

CREATE INDEX ix_stock_transfers_business_id ON stock_transfers (business_id);

CREATE INDEX ix_stock_transfers_created_by ON stock_transfers (created_by);

CREATE INDEX ix_stock_transfers_destination_branch_id ON stock_transfers (destination_branch_id);

CREATE INDEX ix_stock_transfers_received_by ON stock_transfers (received_by);

CREATE INDEX ix_stock_transfers_source_branch_id ON stock_transfers (source_branch_id);

CREATE INDEX ix_stock_transfers_transfer_no ON stock_transfers (transfer_no);

CREATE TABLE stock_transfer_items (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    transfer_id UUID NOT NULL, 
    product_variant_id UUID NOT NULL, 
    quantity NUMERIC(12, 4) NOT NULL, 
    unit_cost NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_stock_transfer_item_qty_positive CHECK (quantity > 0), 
    CONSTRAINT chk_stock_transfer_item_cost_non_negative CHECK (unit_cost >= 0), 
    FOREIGN KEY(product_variant_id) REFERENCES product_variants (id) ON DELETE RESTRICT, 
    FOREIGN KEY(transfer_id) REFERENCES stock_transfers (id) ON DELETE CASCADE
);

CREATE INDEX ix_stock_transfer_items_product_variant_id ON stock_transfer_items (product_variant_id);

CREATE INDEX ix_stock_transfer_items_transfer_id ON stock_transfer_items (transfer_id);

ALTER TABLE imei_devices ADD CONSTRAINT fk_imei_devices_sold_sale_item_id FOREIGN KEY(sold_sale_item_id) REFERENCES sale_items (id) ON DELETE RESTRICT;

UPDATE alembic_version SET version_num='254c6db01cfc' WHERE alembic_version.version_num = 'b29d10e5f2a1';

-- Running upgrade 254c6db01cfc -> c38f19e4a2b1

CREATE TABLE held_carts (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    cashier_id UUID NOT NULL, 
    customer_id UUID, 
    customer_name VARCHAR(255), 
    label VARCHAR(100), 
    cart_items_json JSONB NOT NULL, 
    cart_discount NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    tax_rate NUMERIC(5, 4) DEFAULT 0.0000 NOT NULL, 
    delivery_charge NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    notes TEXT, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(cashier_id) REFERENCES users (id) ON DELETE RESTRICT, 
    FOREIGN KEY(customer_id) REFERENCES customers (id) ON DELETE SET NULL
);

CREATE INDEX ix_held_carts_business_id ON held_carts (business_id);

CREATE INDEX ix_held_carts_branch_id ON held_carts (branch_id);

CREATE INDEX ix_held_carts_cashier_id ON held_carts (cashier_id);

CREATE INDEX ix_held_carts_customer_id ON held_carts (customer_id);

CREATE TABLE quotations (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    quotation_no VARCHAR(100) NOT NULL, 
    customer_id UUID, 
    customer_name VARCHAR(255), 
    status VARCHAR(32) DEFAULT 'DRAFT' NOT NULL, 
    subtotal NUMERIC(19, 4) NOT NULL, 
    discount_total NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    tax_total NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    delivery_charge NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    grand_total NUMERIC(19, 4) NOT NULL, 
    valid_until TIMESTAMP WITHOUT TIME ZONE, 
    notes TEXT, 
    created_by UUID NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    converted_sale_id UUID, 
    PRIMARY KEY (id), 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(converted_sale_id) REFERENCES sales (id) ON DELETE SET NULL, 
    FOREIGN KEY(created_by) REFERENCES users (id) ON DELETE RESTRICT, 
    FOREIGN KEY(customer_id) REFERENCES customers (id) ON DELETE SET NULL, 
    CONSTRAINT uq_quotations_business_no UNIQUE (business_id, quotation_no)
);

CREATE INDEX ix_quotations_business_id ON quotations (business_id);

CREATE INDEX ix_quotations_branch_id ON quotations (branch_id);

CREATE INDEX ix_quotations_created_by ON quotations (created_by);

CREATE INDEX ix_quotations_customer_id ON quotations (customer_id);

CREATE INDEX ix_quotations_quotation_no ON quotations (quotation_no);

CREATE TABLE quotation_items (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    quotation_id UUID NOT NULL, 
    product_variant_id UUID NOT NULL, 
    quantity NUMERIC(12, 4) NOT NULL, 
    unit_price NUMERIC(19, 4) NOT NULL, 
    discount NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    line_total NUMERIC(19, 4) NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(product_variant_id) REFERENCES product_variants (id) ON DELETE RESTRICT, 
    FOREIGN KEY(quotation_id) REFERENCES quotations (id) ON DELETE CASCADE
);

CREATE INDEX ix_quotation_items_product_variant_id ON quotation_items (product_variant_id);

CREATE INDEX ix_quotation_items_quotation_id ON quotation_items (quotation_id);

ALTER TABLE sales ADD COLUMN delivery_charge NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL;

ALTER TABLE sales ADD COLUMN sale_type VARCHAR(32) DEFAULT 'RETAIL' NOT NULL;

ALTER TABLE sales ADD COLUMN manager_approved_by UUID;

ALTER TABLE sales ADD COLUMN exchange_return_id UUID;

ALTER TABLE sales ADD CONSTRAINT fk_sales_manager_approved_by FOREIGN KEY(manager_approved_by) REFERENCES users (id) ON DELETE SET NULL;

ALTER TABLE sales ADD CONSTRAINT fk_sales_exchange_return_id FOREIGN KEY(exchange_return_id) REFERENCES returns (id) ON DELETE SET NULL;

CREATE INDEX ix_sales_manager_approved_by ON sales (manager_approved_by);

CREATE INDEX ix_sales_exchange_return_id ON sales (exchange_return_id);

ALTER TABLE sale_items ADD COLUMN discount_type VARCHAR(20) DEFAULT 'FIXED' NOT NULL;

ALTER TABLE sale_items ADD COLUMN discount_reason VARCHAR(100);

UPDATE alembic_version SET version_num='c38f19e4a2b1' WHERE alembic_version.version_num = '254c6db01cfc';

-- Running upgrade c38f19e4a2b1 -> d49e20f5b3c2

CREATE TABLE expense_categories (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    name VARCHAR(100) NOT NULL, 
    code VARCHAR(50) NOT NULL, 
    description TEXT, 
    monthly_budget NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    CONSTRAINT uq_expense_category_biz_code UNIQUE (business_id, code)
);

CREATE INDEX ix_expense_categories_business_id ON expense_categories (business_id);

CREATE TABLE financial_accounts (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID, 
    account_name VARCHAR(100) NOT NULL, 
    account_type VARCHAR(32) NOT NULL, 
    account_number VARCHAR(100), 
    bank_name VARCHAR(100), 
    opening_balance NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    current_balance NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_financial_account_type CHECK (account_type IN ('CASH_DRAWER', 'SAFE', 'BANK', 'MOBILE_WALLET', 'PETTY_CASH')), 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT
);

CREATE INDEX ix_financial_accounts_business_id ON financial_accounts (business_id);

CREATE INDEX ix_financial_accounts_branch_id ON financial_accounts (branch_id);

CREATE TABLE account_transfers (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    from_account_id UUID NOT NULL, 
    to_account_id UUID NOT NULL, 
    amount NUMERIC(19, 4) NOT NULL, 
    reference_no VARCHAR(100), 
    note TEXT, 
    transfer_date TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    created_by UUID NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_transfer_amount_positive CHECK (amount > 0), 
    CONSTRAINT chk_transfer_diff_accounts CHECK (from_account_id <> to_account_id), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(created_by) REFERENCES users (id) ON DELETE RESTRICT, 
    FOREIGN KEY(from_account_id) REFERENCES financial_accounts (id) ON DELETE RESTRICT, 
    FOREIGN KEY(to_account_id) REFERENCES financial_accounts (id) ON DELETE RESTRICT
);

CREATE INDEX ix_account_transfers_business_id ON account_transfers (business_id);

CREATE INDEX ix_account_transfers_created_by ON account_transfers (created_by);

CREATE INDEX ix_account_transfers_from_account_id ON account_transfers (from_account_id);

CREATE INDEX ix_account_transfers_to_account_id ON account_transfers (to_account_id);

CREATE TABLE recurring_expenses (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID, 
    category_id UUID NOT NULL, 
    payment_account_id UUID, 
    title VARCHAR(150) NOT NULL, 
    amount NUMERIC(19, 4) NOT NULL, 
    frequency VARCHAR(32) NOT NULL, 
    next_due_date DATE NOT NULL, 
    last_generated_at TIMESTAMP WITHOUT TIME ZONE, 
    auto_post BOOLEAN DEFAULT false NOT NULL, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_recurring_amount_positive CHECK (amount > 0), 
    CONSTRAINT chk_recurring_frequency CHECK (frequency IN ('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'ANNUAL')), 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(category_id) REFERENCES expense_categories (id) ON DELETE RESTRICT, 
    FOREIGN KEY(payment_account_id) REFERENCES financial_accounts (id) ON DELETE SET NULL
);

CREATE INDEX ix_recurring_expenses_branch_id ON recurring_expenses (branch_id);

CREATE INDEX ix_recurring_expenses_business_id ON recurring_expenses (business_id);

CREATE INDEX ix_recurring_expenses_category_id ON recurring_expenses (category_id);

CREATE INDEX ix_recurring_expenses_payment_account_id ON recurring_expenses (payment_account_id);

ALTER TABLE expenses ADD COLUMN voucher_no VARCHAR(50);

CREATE INDEX ix_expenses_voucher_no ON expenses (voucher_no);

ALTER TABLE expenses ADD COLUMN category_id UUID;

ALTER TABLE expenses ADD CONSTRAINT fk_expenses_category_id FOREIGN KEY(category_id) REFERENCES expense_categories (id) ON DELETE SET NULL;

CREATE INDEX ix_expenses_category_id ON expenses (category_id);

ALTER TABLE expenses ADD COLUMN payment_account_id UUID;

ALTER TABLE expenses ADD CONSTRAINT fk_expenses_payment_account_id FOREIGN KEY(payment_account_id) REFERENCES financial_accounts (id) ON DELETE SET NULL;

CREATE INDEX ix_expenses_payment_account_id ON expenses (payment_account_id);

ALTER TABLE expenses ADD COLUMN payment_method VARCHAR(32) DEFAULT 'CASH' NOT NULL;

ALTER TABLE expenses ADD COLUMN payee VARCHAR(200);

ALTER TABLE expenses ADD COLUMN receipt_reference VARCHAR(100);

ALTER TABLE expenses ADD COLUMN tax_deductible BOOLEAN DEFAULT true NOT NULL;

ALTER TABLE expenses ADD COLUMN approval_status VARCHAR(32) DEFAULT 'APPROVED' NOT NULL;

ALTER TABLE expenses ADD COLUMN approved_by UUID;

ALTER TABLE expenses ADD CONSTRAINT fk_expenses_approved_by FOREIGN KEY(approved_by) REFERENCES users (id) ON DELETE SET NULL;

ALTER TABLE expenses ADD COLUMN approved_at TIMESTAMP WITHOUT TIME ZONE;

ALTER TABLE expenses ADD CONSTRAINT chk_expense_approval_status CHECK (approval_status IN ('APPROVED', 'PENDING_APPROVAL', 'REJECTED'));

UPDATE alembic_version SET version_num='d49e20f5b3c2' WHERE alembic_version.version_num = 'c38f19e4a2b1';

-- Running upgrade d49e20f5b3c2 -> e50f31a1b4d3

ALTER TABLE branches ADD COLUMN branch_type VARCHAR(32) DEFAULT 'RETAIL_STORE' NOT NULL;

ALTER TABLE product_variants ADD COLUMN has_batch_tracking BOOLEAN DEFAULT false NOT NULL;

ALTER TABLE product_variants ADD COLUMN min_stock_level NUMERIC(12, 4) DEFAULT 0.0000 NOT NULL;

ALTER TABLE product_variants ADD COLUMN reorder_quantity NUMERIC(12, 4) DEFAULT 0.0000 NOT NULL;

CREATE TABLE inventory_batches (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    product_variant_id UUID NOT NULL, 
    batch_number VARCHAR(100) NOT NULL, 
    manufacturing_date DATE, 
    expiry_date DATE, 
    quantity_received NUMERIC(12, 4) NOT NULL, 
    quantity_on_hand NUMERIC(12, 4) NOT NULL, 
    cost_price NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    supplier_id UUID, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_batch_qty_received_positive CHECK (quantity_received > 0), 
    CONSTRAINT chk_batch_qty_on_hand_non_negative CHECK (quantity_on_hand >= 0), 
    CONSTRAINT chk_batch_cost_price_non_negative CHECK (cost_price >= 0), 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(product_variant_id) REFERENCES product_variants (id) ON DELETE RESTRICT, 
    FOREIGN KEY(supplier_id) REFERENCES suppliers (id) ON DELETE SET NULL, 
    CONSTRAINT uq_batches_biz_branch_variant_batch UNIQUE (business_id, branch_id, product_variant_id, batch_number)
);

CREATE INDEX ix_inventory_batches_business_id ON inventory_batches (business_id);

CREATE INDEX ix_inventory_batches_branch_id ON inventory_batches (branch_id);

CREATE INDEX ix_inventory_batches_product_variant_id ON inventory_batches (product_variant_id);

CREATE INDEX ix_inventory_batches_supplier_id ON inventory_batches (supplier_id);

CREATE INDEX ix_inventory_batches_expiry ON inventory_batches (business_id, branch_id, expiry_date);

CREATE INDEX ix_inventory_batches_variant ON inventory_batches (product_variant_id, is_active);

ALTER TABLE stock_movements ADD COLUMN batch_id UUID;

CREATE INDEX ix_stock_movements_batch_id ON stock_movements (batch_id);

ALTER TABLE stock_movements ADD CONSTRAINT fk_stock_movements_batch_id FOREIGN KEY(batch_id) REFERENCES inventory_batches (id) ON DELETE SET NULL;

CREATE TABLE damaged_stock_records (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    product_variant_id UUID NOT NULL, 
    batch_id UUID, 
    voucher_no VARCHAR(50) NOT NULL, 
    quantity NUMERIC(12, 4) NOT NULL, 
    unit_cost NUMERIC(19, 4) NOT NULL, 
    total_loss NUMERIC(19, 4) NOT NULL, 
    reason VARCHAR(50) NOT NULL, 
    disposal_method VARCHAR(50) NOT NULL, 
    notes TEXT, 
    reported_by UUID NOT NULL, 
    approved_by UUID, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_damaged_qty_positive CHECK (quantity > 0), 
    CONSTRAINT chk_damaged_cost_non_negative CHECK (unit_cost >= 0), 
    CONSTRAINT chk_damaged_loss_non_negative CHECK (total_loss >= 0), 
    CONSTRAINT chk_damaged_reason CHECK (reason IN ('EXPIRED', 'BROKEN', 'TRANSIT_DAMAGE', 'WATER_DAMAGE', 'THEFT', 'OTHER')), 
    CONSTRAINT chk_damaged_disposal_method CHECK (disposal_method IN ('DESTROYED', 'RETURNED_TO_VENDOR', 'SOLD_AT_DISCOUNT', 'WRITTEN_OFF')), 
    FOREIGN KEY(approved_by) REFERENCES users (id) ON DELETE SET NULL, 
    FOREIGN KEY(batch_id) REFERENCES inventory_batches (id) ON DELETE SET NULL, 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(product_variant_id) REFERENCES product_variants (id) ON DELETE RESTRICT, 
    FOREIGN KEY(reported_by) REFERENCES users (id) ON DELETE RESTRICT
);

CREATE INDEX ix_damaged_stock_records_business_id ON damaged_stock_records (business_id);

CREATE INDEX ix_damaged_stock_records_branch_id ON damaged_stock_records (branch_id);

CREATE INDEX ix_damaged_stock_records_product_variant_id ON damaged_stock_records (product_variant_id);

CREATE INDEX ix_damaged_stock_records_batch_id ON damaged_stock_records (batch_id);

CREATE INDEX ix_damaged_stock_records_voucher_no ON damaged_stock_records (voucher_no);

CREATE INDEX ix_damaged_stock_records_reported_by ON damaged_stock_records (reported_by);

CREATE INDEX ix_damaged_stock_records_created_at ON damaged_stock_records (created_at);

CREATE TABLE stock_reservations (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    product_variant_id UUID NOT NULL, 
    batch_id UUID, 
    quantity NUMERIC(12, 4) NOT NULL, 
    reference_type VARCHAR(50) NOT NULL, 
    reference_id UUID NOT NULL, 
    status VARCHAR(32) DEFAULT 'ACTIVE' NOT NULL, 
    reserved_until TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
    created_by UUID NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_reservation_qty_positive CHECK (quantity > 0), 
    CONSTRAINT chk_reservation_ref_type CHECK (reference_type IN ('QUOTATION', 'LAYAWAY', 'SALES_ORDER')), 
    CONSTRAINT chk_reservation_status CHECK (status IN ('ACTIVE', 'FULFILLED', 'RELEASED', 'EXPIRED')), 
    FOREIGN KEY(batch_id) REFERENCES inventory_batches (id) ON DELETE SET NULL, 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE RESTRICT, 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(created_by) REFERENCES users (id) ON DELETE RESTRICT, 
    FOREIGN KEY(product_variant_id) REFERENCES product_variants (id) ON DELETE RESTRICT
);

CREATE INDEX ix_stock_reservations_business_id ON stock_reservations (business_id);

CREATE INDEX ix_stock_reservations_branch_id ON stock_reservations (branch_id);

CREATE INDEX ix_stock_reservations_product_variant_id ON stock_reservations (product_variant_id);

CREATE INDEX ix_stock_reservations_batch_id ON stock_reservations (batch_id);

CREATE INDEX ix_stock_reservations_reference_id ON stock_reservations (reference_id);

CREATE INDEX ix_stock_reservations_created_by ON stock_reservations (created_by);

CREATE INDEX ix_stock_reservations_created_at ON stock_reservations (created_at);

CREATE INDEX ix_stock_reservations_lookup ON stock_reservations (business_id, branch_id, product_variant_id, status);

UPDATE alembic_version SET version_num='e50f31a1b4d3' WHERE alembic_version.version_num = 'd49e20f5b3c2';

-- Running upgrade e50f31a1b4d3 -> f61g42b2c5e4

CREATE TABLE customer_groups (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    name VARCHAR(100) NOT NULL, 
    description TEXT, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT uq_customer_groups_business_name UNIQUE (business_id, name), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT
);

CREATE INDEX ix_customer_groups_business ON customer_groups (business_id);

CREATE TABLE customer_group_members (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    customer_group_id UUID NOT NULL, 
    customer_id UUID NOT NULL, 
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT uq_customer_group_members_group_customer UNIQUE (customer_group_id, customer_id), 
    FOREIGN KEY(customer_group_id) REFERENCES customer_groups (id) ON DELETE CASCADE, 
    FOREIGN KEY(customer_id) REFERENCES customers (id) ON DELETE CASCADE
);

CREATE INDEX ix_customer_group_members_group ON customer_group_members (customer_group_id);

CREATE INDEX ix_customer_group_members_customer ON customer_group_members (customer_id);

CREATE TABLE price_lists (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    name VARCHAR(100) NOT NULL, 
    description TEXT, 
    currency VARCHAR(10) DEFAULT 'BDT' NOT NULL, 
    is_default BOOLEAN DEFAULT false NOT NULL, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    customer_group_id UUID, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT uq_price_lists_business_name UNIQUE (business_id, name), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(customer_group_id) REFERENCES customer_groups (id) ON DELETE SET NULL
);

CREATE INDEX ix_price_lists_business ON price_lists (business_id);

CREATE UNIQUE INDEX uq_price_lists_business_default ON price_lists (business_id) WHERE is_default = true;

CREATE TABLE price_list_items (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    price_list_id UUID NOT NULL, 
    product_variant_id UUID NOT NULL, 
    min_quantity NUMERIC(12, 4) DEFAULT 1.0000 NOT NULL, 
    price NUMERIC(19, 4) NOT NULL, 
    start_date DATE, 
    end_date DATE, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT uq_price_list_items_list_var_minqty UNIQUE (price_list_id, product_variant_id, min_quantity), 
    CONSTRAINT chk_price_list_items_min_qty_pos CHECK (min_quantity > 0), 
    CONSTRAINT chk_price_list_items_price_non_neg CHECK (price >= 0), 
    FOREIGN KEY(price_list_id) REFERENCES price_lists (id) ON DELETE CASCADE, 
    FOREIGN KEY(product_variant_id) REFERENCES product_variants (id) ON DELETE CASCADE
);

CREATE INDEX ix_price_list_items_variant ON price_list_items (product_variant_id);

CREATE INDEX ix_price_list_items_list ON price_list_items (price_list_id);

CREATE TABLE branch_price_overrides (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    branch_id UUID NOT NULL, 
    product_variant_id UUID NOT NULL, 
    selling_price NUMERIC(19, 4) NOT NULL, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT uq_branch_overrides_branch_variant UNIQUE (branch_id, product_variant_id), 
    CONSTRAINT chk_branch_overrides_price_non_neg CHECK (selling_price >= 0), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(branch_id) REFERENCES branches (id) ON DELETE CASCADE, 
    FOREIGN KEY(product_variant_id) REFERENCES product_variants (id) ON DELETE CASCADE
);

CREATE INDEX ix_branch_overrides_business ON branch_price_overrides (business_id);

CREATE INDEX ix_branch_overrides_branch ON branch_price_overrides (branch_id);

CREATE INDEX ix_branch_overrides_variant ON branch_price_overrides (product_variant_id);

CREATE TABLE product_bundles (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    product_id UUID NOT NULL, 
    name VARCHAR(255) NOT NULL, 
    bundle_price NUMERIC(19, 4), 
    is_kit BOOLEAN DEFAULT false NOT NULL, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT uq_product_bundles_business_product UNIQUE (business_id, product_id), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT, 
    FOREIGN KEY(product_id) REFERENCES products (id) ON DELETE RESTRICT
);

CREATE INDEX ix_product_bundles_business ON product_bundles (business_id);

CREATE TABLE product_bundle_items (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    bundle_id UUID NOT NULL, 
    component_variant_id UUID NOT NULL, 
    quantity NUMERIC(12, 4) NOT NULL, 
    is_optional BOOLEAN DEFAULT false NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT uq_product_bundle_items_bundle_component UNIQUE (bundle_id, component_variant_id), 
    CONSTRAINT chk_product_bundle_items_qty_pos CHECK (quantity > 0), 
    FOREIGN KEY(bundle_id) REFERENCES product_bundles (id) ON DELETE CASCADE, 
    FOREIGN KEY(component_variant_id) REFERENCES product_variants (id) ON DELETE RESTRICT
);

CREATE INDEX ix_product_bundle_items_bundle ON product_bundle_items (bundle_id);

CREATE INDEX ix_product_bundle_items_component ON product_bundle_items (component_variant_id);

CREATE TABLE promotions (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    name VARCHAR(255) NOT NULL, 
    code VARCHAR(50), 
    discount_type VARCHAR(20) NOT NULL, 
    discount_value NUMERIC(19, 4) NOT NULL, 
    min_spend NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    max_discount_cap NUMERIC(19, 4), 
    usage_limit INTEGER, 
    times_used INTEGER DEFAULT 0 NOT NULL, 
    valid_from DATE NOT NULL, 
    valid_until DATE NOT NULL, 
    applies_to VARCHAR(20) DEFAULT 'ALL' NOT NULL, 
    scope_ids JSONB DEFAULT '[]'::jsonb NOT NULL, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_promotions_discount_value_pos CHECK (discount_value > 0), 
    CONSTRAINT chk_promotions_min_spend_non_neg CHECK (min_spend >= 0), 
    CONSTRAINT chk_promotions_times_used_non_neg CHECK (times_used >= 0), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE RESTRICT
);

CREATE INDEX ix_promotions_business ON promotions (business_id);

CREATE UNIQUE INDEX uq_promotions_business_code ON promotions (business_id, code) WHERE code IS NOT NULL;

CREATE TABLE promotion_usages (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    promotion_id UUID NOT NULL, 
    sale_id UUID NOT NULL, 
    discount_applied NUMERIC(19, 4) NOT NULL, 
    used_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT uq_promotion_usages_promo_sale UNIQUE (promotion_id, sale_id), 
    FOREIGN KEY(promotion_id) REFERENCES promotions (id) ON DELETE RESTRICT, 
    FOREIGN KEY(sale_id) REFERENCES sales (id) ON DELETE RESTRICT
);

CREATE INDEX ix_promotion_usages_promo ON promotion_usages (promotion_id);

CREATE INDEX ix_promotion_usages_sale ON promotion_usages (sale_id);

ALTER TABLE customers ADD COLUMN primary_group_id UUID;

ALTER TABLE customers ADD FOREIGN KEY(primary_group_id) REFERENCES customer_groups (id) ON DELETE SET NULL;

CREATE INDEX ix_customers_primary_group ON customers (primary_group_id);

ALTER TABLE sales ADD COLUMN promotion_id UUID;

ALTER TABLE sales ADD FOREIGN KEY(promotion_id) REFERENCES promotions (id) ON DELETE SET NULL;

ALTER TABLE sales ADD COLUMN promotion_code VARCHAR(50);

ALTER TABLE sales ADD COLUMN promotion_discount NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL;

ALTER TABLE sales ADD COLUMN price_list_id UUID;

ALTER TABLE sales ADD FOREIGN KEY(price_list_id) REFERENCES price_lists (id) ON DELETE SET NULL;

CREATE INDEX ix_sales_promotion_id ON sales (promotion_id);

CREATE INDEX ix_sales_price_list_id ON sales (price_list_id);

UPDATE alembic_version SET version_num='f61g42b2c5e4' WHERE alembic_version.version_num = 'e50f31a1b4d3';

-- Running upgrade f61g42b2c5e4 -> a72h53c3d6f5

CREATE TABLE loyalty_settings (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    is_enabled BOOLEAN DEFAULT true NOT NULL, 
    earn_rate NUMERIC(10, 4) DEFAULT 1.0000 NOT NULL, 
    redeem_rate NUMERIC(10, 4) DEFAULT 0.1000 NOT NULL, 
    min_redeem_points INTEGER DEFAULT 100 NOT NULL, 
    points_expiry_days INTEGER DEFAULT 365 NOT NULL, 
    max_cart_discount_pct NUMERIC(5, 2) DEFAULT 50.00 NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT uq_loyalty_settings_business UNIQUE (business_id), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE CASCADE
);

CREATE INDEX ix_loyalty_settings_business ON loyalty_settings (business_id);

CREATE TABLE membership_tiers (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    name VARCHAR(50) NOT NULL, 
    code VARCHAR(30) NOT NULL, 
    min_spend NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL, 
    points_multiplier NUMERIC(5, 2) DEFAULT 1.00 NOT NULL, 
    discount_pct NUMERIC(5, 2) DEFAULT 0.00 NOT NULL, 
    badge_color VARCHAR(20) DEFAULT '#64748B' NOT NULL, 
    perks_description TEXT, 
    sort_order INTEGER DEFAULT 0 NOT NULL, 
    is_active BOOLEAN DEFAULT true NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT uq_membership_tiers_business_code UNIQUE (business_id, code), 
    CONSTRAINT chk_tier_min_spend_non_negative CHECK (min_spend >= 0), 
    CONSTRAINT chk_tier_multiplier_positive CHECK (points_multiplier > 0), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE CASCADE
);

CREATE INDEX ix_membership_tiers_business ON membership_tiers (business_id);

CREATE TABLE loyalty_transactions (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    customer_id UUID NOT NULL, 
    sale_id UUID, 
    transaction_type VARCHAR(20) NOT NULL, 
    points INTEGER NOT NULL, 
    points_balance_after INTEGER NOT NULL, 
    reason VARCHAR(255), 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_loyalty_balance_non_negative CHECK (points_balance_after >= 0), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE CASCADE, 
    FOREIGN KEY(customer_id) REFERENCES customers (id) ON DELETE RESTRICT, 
    FOREIGN KEY(sale_id) REFERENCES sales (id) ON DELETE SET NULL
);

CREATE INDEX ix_loyalty_tx_business ON loyalty_transactions (business_id);

CREATE INDEX ix_loyalty_tx_customer ON loyalty_transactions (customer_id, created_at);

CREATE INDEX ix_loyalty_tx_sale ON loyalty_transactions (sale_id);

CREATE TABLE gift_cards (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    card_number VARCHAR(32) NOT NULL, 
    pin_hash VARCHAR(128) NOT NULL, 
    initial_balance NUMERIC(19, 4) NOT NULL, 
    current_balance NUMERIC(19, 4) NOT NULL, 
    status VARCHAR(20) DEFAULT 'ACTIVE' NOT NULL, 
    purchaser_customer_id UUID, 
    recipient_name VARCHAR(100), 
    recipient_phone VARCHAR(50), 
    recipient_email VARCHAR(100), 
    expires_at TIMESTAMP WITH TIME ZONE, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT uq_gift_cards_business_number UNIQUE (business_id, card_number), 
    CONSTRAINT chk_gift_card_balance_non_negative CHECK (current_balance >= 0), 
    CONSTRAINT chk_gift_card_initial_non_negative CHECK (initial_balance >= 0), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE CASCADE, 
    FOREIGN KEY(purchaser_customer_id) REFERENCES customers (id) ON DELETE SET NULL
);

CREATE INDEX ix_gift_cards_business ON gift_cards (business_id);

CREATE INDEX ix_gift_cards_number ON gift_cards (card_number);

CREATE TABLE gift_card_transactions (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    gift_card_id UUID NOT NULL, 
    sale_id UUID, 
    transaction_type VARCHAR(20) NOT NULL, 
    amount NUMERIC(19, 4) NOT NULL, 
    balance_after NUMERIC(19, 4) NOT NULL, 
    reference VARCHAR(100), 
    notes TEXT, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT chk_gift_card_tx_balance_non_negative CHECK (balance_after >= 0), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE CASCADE, 
    FOREIGN KEY(gift_card_id) REFERENCES gift_cards (id) ON DELETE RESTRICT, 
    FOREIGN KEY(sale_id) REFERENCES sales (id) ON DELETE SET NULL
);

CREATE INDEX ix_gift_card_tx_business ON gift_card_transactions (business_id);

CREATE INDEX ix_gift_card_tx_card ON gift_card_transactions (gift_card_id, created_at);

CREATE TABLE credit_notes (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    customer_id UUID NOT NULL, 
    sale_return_id UUID, 
    note_number VARCHAR(50) NOT NULL, 
    initial_amount NUMERIC(19, 4) NOT NULL, 
    remaining_balance NUMERIC(19, 4) NOT NULL, 
    status VARCHAR(20) DEFAULT 'ACTIVE' NOT NULL, 
    reason VARCHAR(255) NOT NULL, 
    expires_at TIMESTAMP WITH TIME ZONE, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT uq_credit_notes_business_number UNIQUE (business_id, note_number), 
    CONSTRAINT chk_credit_note_balance_non_negative CHECK (remaining_balance >= 0), 
    CONSTRAINT chk_credit_note_initial_non_negative CHECK (initial_amount >= 0), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE CASCADE, 
    FOREIGN KEY(customer_id) REFERENCES customers (id) ON DELETE RESTRICT, 
    FOREIGN KEY(sale_return_id) REFERENCES returns (id) ON DELETE SET NULL
);

CREATE INDEX ix_credit_notes_business ON credit_notes (business_id);

CREATE INDEX ix_credit_notes_customer ON credit_notes (customer_id);

CREATE TABLE promotional_campaigns (
    id UUID DEFAULT gen_random_uuid() NOT NULL, 
    business_id UUID NOT NULL, 
    title VARCHAR(120) NOT NULL, 
    target_segment VARCHAR(50) DEFAULT 'ALL' NOT NULL, 
    target_group_id UUID, 
    channel VARCHAR(20) DEFAULT 'SMS' NOT NULL, 
    message_template TEXT NOT NULL, 
    promotion_id UUID, 
    audience_count INTEGER DEFAULT 0 NOT NULL, 
    status VARCHAR(20) DEFAULT 'DRAFT' NOT NULL, 
    scheduled_at TIMESTAMP WITH TIME ZONE, 
    sent_at TIMESTAMP WITH TIME ZONE, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(business_id) REFERENCES businesses (id) ON DELETE CASCADE, 
    FOREIGN KEY(target_group_id) REFERENCES customer_groups (id) ON DELETE SET NULL, 
    FOREIGN KEY(promotion_id) REFERENCES promotions (id) ON DELETE SET NULL
);

CREATE INDEX ix_promotional_campaigns_business ON promotional_campaigns (business_id);

ALTER TABLE customers ADD COLUMN loyalty_points_balance INTEGER DEFAULT 0 NOT NULL;

ALTER TABLE customers ADD COLUMN membership_tier_id UUID;

ALTER TABLE customers ADD FOREIGN KEY(membership_tier_id) REFERENCES membership_tiers (id) ON DELETE SET NULL;

ALTER TABLE customers ADD COLUMN store_credit_balance NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL;

ALTER TABLE customers ADD COLUMN lifetime_spend NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL;

ALTER TABLE customers ADD COLUMN rfm_segment VARCHAR(50) DEFAULT 'NEW_CUSTOMER';

ALTER TABLE customers ADD CONSTRAINT chk_customer_points_non_negative CHECK (loyalty_points_balance >= 0);

ALTER TABLE customers ADD CONSTRAINT chk_customer_store_credit_non_negative CHECK (store_credit_balance >= 0);

ALTER TABLE customers ADD CONSTRAINT chk_customer_lifetime_spend_non_negative CHECK (lifetime_spend >= 0);

ALTER TABLE sales ADD COLUMN loyalty_points_earned INTEGER DEFAULT 0 NOT NULL;

ALTER TABLE sales ADD COLUMN loyalty_points_redeemed INTEGER DEFAULT 0 NOT NULL;

ALTER TABLE sales ADD COLUMN loyalty_discount NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL;

ALTER TABLE sales ADD COLUMN gift_card_discount NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL;

ALTER TABLE sales ADD COLUMN store_credit_discount NUMERIC(19, 4) DEFAULT 0.0000 NOT NULL;

UPDATE alembic_version SET version_num='a72h53c3d6f5' WHERE alembic_version.version_num = 'f61g42b2c5e4';

COMMIT;

