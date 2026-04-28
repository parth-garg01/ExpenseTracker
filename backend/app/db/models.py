import uuid

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Numeric, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class User(Base):
    __tablename__ = 'users'

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)


class ShopType(Base):
    __tablename__ = 'shop_types'

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(120), unique=True, nullable=False)


class Vendor(Base):
    __tablename__ = 'vendors'

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    normalized_name: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    shop_type_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey('shop_types.id'))

    shop_type: Mapped[ShopType | None] = relationship()


class Transaction(Base):
    __tablename__ = 'transactions'
    __table_args__ = (
        CheckConstraint("type IN ('debit', 'credit')", name='ck_transactions_type'),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey('users.id'), nullable=False)
    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    type: Mapped[str] = mapped_column(String(10), nullable=False)
    vendor_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey('vendors.id'))
    raw_vendor_name: Mapped[str] = mapped_column(String(255), nullable=False)
    vendor_name: Mapped[str | None] = mapped_column(String(255))
    shop_type: Mapped[str] = mapped_column(String(120), default='Anonymous')
    tx_timestamp: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    upi_reference: Mapped[str | None] = mapped_column(String(64))
    description: Mapped[str | None] = mapped_column(Text)
    is_synced: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())

    vendor: Mapped[Vendor | None] = relationship()
