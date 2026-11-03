"""Business service for customer CRM, credit limits, and due debt collection."""

import uuid
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.customers.repository import CustomersRepository
from app.modules.customers.schemas import (
    AllocatedSalePayment,
    CustomerCreate,
    CustomerDuePaymentOut,
    CustomerDuePaymentRequest,
    CustomerLedgerEntry,
    CustomerOut,
    CustomerUpdate,
    PaginatedCustomers,
)
from app.modules.expenses.models import CashTransaction
from app.modules.sales.models import Customer, PaymentTender
from app.shared.exceptions import AppException


class CustomersService:
    """Orchestrates customer account operations, credit validation, and debt settlement."""

    def __init__(self, repo: CustomersRepository | None = None) -> None:
        self.repo = repo or CustomersRepository()

    async def create_customer(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        payload: CustomerCreate,
    ) -> CustomerOut:
        """Creates a new customer, enforcing unique phone number per business."""
        if payload.phone:
            existing = await self.repo.get_by_phone(session, business_id, payload.phone)
            if existing:
                raise AppException(
                    f"A customer with phone number '{payload.phone}' already exists",
                    code="PHONE_ALREADY_EXISTS",
                    status_code=409,
                    details={"phone": payload.phone},
                )

        customer = Customer(
            id=uuid.uuid4(),
            business_id=business_id,
            name=payload.name.strip(),
            phone=payload.phone,
            email=payload.email.strip() if payload.email else None,
            address=payload.address.strip() if payload.address else None,
            credit_limit=payload.credit_limit,
            is_active=payload.is_active,
        )
        await self.repo.create(session, customer)
        await session.commit()
        await session.refresh(customer)

        return CustomerOut(
            id=customer.id,
            business_id=customer.business_id,
            name=customer.name,
            phone=customer.phone,
            email=customer.email,
            address=customer.address,
            credit_limit=customer.credit_limit,
            due_balance=Decimal("0.0000"),
            available_credit=customer.credit_limit,
            total_sales_count=0,
            total_spent=Decimal("0.0000"),
            is_active=customer.is_active,
            created_at=customer.created_at,
        )

    async def update_customer(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        customer_id: uuid.UUID,
        payload: CustomerUpdate,
    ) -> CustomerOut:
        """Updates customer profile details and credit limits."""
        customer = await self.repo.get_by_id(session, business_id, customer_id)
        if not customer:
            raise AppException("Customer not found", code="CUSTOMER_NOT_FOUND", status_code=404)

        if payload.phone and payload.phone != customer.phone:
            existing = await self.repo.get_by_phone(session, business_id, payload.phone)
            if existing and existing.id != customer.id:
                raise AppException(
                    f"Phone number '{payload.phone}' is already registered to another customer",
                    code="PHONE_ALREADY_EXISTS",
                    status_code=409,
                    details={"phone": payload.phone},
                )
            customer.phone = payload.phone

        if payload.name is not None:
            customer.name = payload.name.strip()
        if payload.email is not None:
            customer.email = payload.email.strip() if payload.email else None
        if payload.address is not None:
            customer.address = payload.address.strip() if payload.address else None
        if payload.credit_limit is not None:
            customer.credit_limit = payload.credit_limit
        if payload.is_active is not None:
            customer.is_active = payload.is_active

        await session.commit()
        await session.refresh(customer)

        due, count, spent = await self.repo.get_customer_financial_metrics(
            session, business_id, customer_id
        )
        available_credit = max(Decimal("0.0000"), customer.credit_limit - due)

        return CustomerOut(
            id=customer.id,
            business_id=customer.business_id,
            name=customer.name,
            phone=customer.phone,
            email=customer.email,
            address=customer.address,
            credit_limit=customer.credit_limit,
            due_balance=due,
            available_credit=available_credit,
            total_sales_count=count,
            total_spent=spent,
            is_active=customer.is_active,
            created_at=customer.created_at,
        )

    async def get_customer(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        customer_id: uuid.UUID,
    ) -> CustomerOut:
        """Retrieves customer with calculated real-time balances."""
        customer = await self.repo.get_by_id(session, business_id, customer_id)
        if not customer:
            raise AppException("Customer not found", code="CUSTOMER_NOT_FOUND", status_code=404)

        due, count, spent = await self.repo.get_customer_financial_metrics(
            session, business_id, customer_id
        )
        available_credit = max(Decimal("0.0000"), customer.credit_limit - due)

        return CustomerOut(
            id=customer.id,
            business_id=customer.business_id,
            name=customer.name,
            phone=customer.phone,
            email=customer.email,
            address=customer.address,
            credit_limit=customer.credit_limit,
            due_balance=due,
            available_credit=available_credit,
            total_sales_count=count,
            total_spent=spent,
            is_active=customer.is_active,
            created_at=customer.created_at,
        )

    async def list_customers(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        search: str | None = None,
        is_active: bool | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> PaginatedCustomers:
        """Fetches paginated customers with batch financial metrics."""
        total = await self.repo.count_customers(session, business_id, search, is_active)
        customers = await self.repo.list_customers(
            session, business_id, search, is_active, page, page_size
        )

        customer_ids = [c.id for c in customers]
        metrics = await self.repo.get_batch_financial_metrics(session, business_id, customer_ids)
        total_outstanding = await self.repo.get_total_business_outstanding_dues(
            session, business_id
        )

        items_out: list[CustomerOut] = []
        for c in customers:
            due, count, spent = metrics.get(
                c.id, (Decimal("0.0000"), 0, Decimal("0.0000"))
            )
            available_credit = max(Decimal("0.0000"), c.credit_limit - due)
            items_out.append(
                CustomerOut(
                    id=c.id,
                    business_id=c.business_id,
                    name=c.name,
                    phone=c.phone,
                    email=c.email,
                    address=c.address,
                    credit_limit=c.credit_limit,
                    due_balance=due,
                    available_credit=available_credit,
                    total_sales_count=count,
                    total_spent=spent,
                    is_active=c.is_active,
                    created_at=c.created_at,
                )
            )

        total_pages = (total + page_size - 1) // page_size if total > 0 else 1

        return PaginatedCustomers(
            items=items_out,
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
            total_outstanding_dues=total_outstanding,
        )

    async def collect_due_payment(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        cashier_id: uuid.UUID,
        customer_id: uuid.UUID,
        payload: CustomerDuePaymentRequest,
    ) -> CustomerDuePaymentOut:
        """Collects debt repayment and allocates it against unpaid sales within an atomic transaction."""
        customer = await self.repo.get_by_id(session, business_id, customer_id, for_update=True)
        if not customer:
            raise AppException("Customer not found", code="CUSTOMER_NOT_FOUND", status_code=404)

        unpaid_sales = await self.repo.get_unpaid_sales_for_update(
            session, business_id, customer_id, payload.sale_id
        )
        if not unpaid_sales:
            raise AppException(
                "Customer has no outstanding dues to repay",
                code="NO_OUTSTANDING_DUES",
                status_code=400,
            )

        total_due_balance = sum((s.due_total for s in unpaid_sales), Decimal("0.0000"))
        if payload.amount > total_due_balance:
            raise AppException(
                f"Tendered payment ৳{payload.amount} exceeds total outstanding due ৳{total_due_balance}",
                code="PAYMENT_EXCEEDS_DUE",
                status_code=400,
                details={"total_due": str(total_due_balance)},
            )

        remaining_to_allocate = payload.amount
        allocated_records: list[AllocatedSalePayment] = []

        for sale in unpaid_sales:
            if remaining_to_allocate <= Decimal("0.0000"):
                break

            alloc_amount = min(remaining_to_allocate, sale.due_total)
            sale.paid_total += alloc_amount
            sale.due_total -= alloc_amount
            remaining_to_allocate -= alloc_amount

            # Insert payment tender against the sale
            tender = PaymentTender(
                id=uuid.uuid4(),
                business_id=business_id,
                sale_id=sale.id,
                method=payload.payment_method,
                amount=alloc_amount,
                reference=payload.reference,
                status="CONFIRMED",
            )
            session.add(tender)

            # Record cash drawer entry if cash tender
            if payload.payment_method == "CASH":
                cash_entry = CashTransaction(
                    id=uuid.uuid4(),
                    business_id=business_id,
                    branch_id=branch_id,
                    account_id="MAIN_CASH_DRAWER",
                    direction="IN",
                    amount=alloc_amount,
                    reference_type="SALE",
                    reference_id=sale.id,
                    note=f"Due repayment collected for {sale.receipt_no}",
                    created_by=cashier_id,
                )
                session.add(cash_entry)

            allocated_records.append(
                AllocatedSalePayment(
                    sale_id=sale.id,
                    receipt_no=sale.receipt_no,
                    allocated_amount=alloc_amount,
                    remaining_sale_due=sale.due_total,
                )
            )

        await session.commit()

        new_due, _, _ = await self.repo.get_customer_financial_metrics(
            session, business_id, customer_id
        )

        return CustomerDuePaymentOut(
            customer_id=customer.id,
            customer_name=customer.name,
            amount_paid=payload.amount,
            previous_due=total_due_balance,
            remaining_due=new_due,
            payment_method=payload.payment_method,
            reference=payload.reference,
            allocated_sales=allocated_records,
            created_at=customer.created_at,
        )

    async def get_customer_ledger(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        customer_id: uuid.UUID,
    ) -> list[CustomerLedgerEntry]:
        """Builds chronological credit/debit statement for customer store credit."""
        sales_with_payments = await self.repo.get_customer_sales_and_tenders_for_ledger(
            session, business_id, customer_id
        )

        events: list[tuple] = []
        for sale, payments in sales_with_payments:
            # Customer account is debited with the total purchase amount
            events.append((
                sale.created_at,
                "SALE_CHARGE",
                sale.receipt_no,
                f"Purchase: {sale.receipt_no}",
                sale.grand_total,
                Decimal("0.0000"),
            ))
            # Real monetary payments (CASH, CARD, BKASH, NAGAD, ROCKET) credit the account
            for p in payments:
                if p.status == "CONFIRMED" and p.method != "DUE":
                    events.append((
                        p.received_at,
                        "PAYMENT",
                        sale.receipt_no,
                        f"Payment ({p.method}) against {sale.receipt_no}",
                        Decimal("0.0000"),
                        p.amount,
                    ))

        # Sort events by timestamp
        events.sort(key=lambda x: x[0])

        running_balance = Decimal("0.0000")
        ledger: list[CustomerLedgerEntry] = []
        for ts, etype, rno, desc, debit, credit in events:
            running_balance += debit - credit
            ledger.append(
                CustomerLedgerEntry(
                    date=ts,
                    entry_type=etype,
                    receipt_no=rno,
                    description=desc,
                    debit=debit,
                    credit=credit,
                    balance=running_balance,
                )
            )

        return ledger
