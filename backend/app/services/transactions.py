from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import ShopType, Transaction, Vendor
from app.services.sms_parser import normalize_vendor_name, parse_sms


def classify_vendor(db: Session, raw_vendor_name: str) -> tuple[Vendor | None, bool]:
    normalized = normalize_vendor_name(raw_vendor_name)
    vendor = db.scalar(select(Vendor).where(Vendor.normalized_name == normalized))
    if vendor:
        return vendor, True
    return None, False


def ingest_sms_transaction(db: Session, user_id: str, sms_body: str) -> dict:
    parsed = parse_sms(sms_body)
    vendor, classified = classify_vendor(db, parsed['raw_vendor_name'])

    tx = Transaction(
        user_id=user_id,
        amount=parsed['amount'],
        type=parsed['type'],
        vendor_id=vendor.id if vendor else None,
        raw_vendor_name=parsed['raw_vendor_name'],
        tx_timestamp=parsed['tx_timestamp'],
        upi_reference=parsed['upi_reference'],
        description=None,
    )
    db.add(tx)
    db.commit()
    db.refresh(tx)

    return {
        'transaction_id': str(tx.id),
        'classified': classified,
        'vendor_name': vendor.name if vendor else parsed['raw_vendor_name'],
        'shop_type': vendor.shop_type.name if vendor and vendor.shop_type else 'Anonymous',
    }


def create_or_update_vendor(db: Session, raw_vendor_name: str, shop_name: str, shop_type_name: str) -> Vendor:
    normalized = normalize_vendor_name(raw_vendor_name)

    shop_type = db.scalar(select(ShopType).where(ShopType.name == shop_type_name))
    if not shop_type:
        shop_type = ShopType(name=shop_type_name)
        db.add(shop_type)
        db.flush()

    vendor = db.scalar(select(Vendor).where(Vendor.normalized_name == normalized))
    if not vendor:
        vendor = Vendor(name=shop_name, normalized_name=normalized, shop_type_id=shop_type.id)
        db.add(vendor)
    else:
        vendor.name = shop_name
        vendor.shop_type_id = shop_type.id

    db.commit()
    db.refresh(vendor)
    return vendor
