from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import Select, select
from sqlalchemy.orm import Session

from app.api.schemas import SmsIngestRequest, VendorClassifyRequest
from app.db.deps import get_db
from app.db.models import Transaction
from app.services.transactions import create_or_update_vendor, ingest_sms_transaction

router = APIRouter(prefix='/api')


@router.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok'}


@router.post('/transactions/ingest-sms')
def ingest_sms(payload: SmsIngestRequest, db: Session = Depends(get_db)) -> dict:
    try:
        return ingest_sms_transaction(db, user_id=payload.user_id, sms_body=payload.sms_body)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post('/vendors/classify')
def classify_vendor(payload: VendorClassifyRequest, db: Session = Depends(get_db)) -> dict:
    vendor = create_or_update_vendor(
        db,
        raw_vendor_name=payload.raw_vendor_name,
        shop_name=payload.shop_name,
        shop_type_name=payload.shop_type_name,
    )
    return {'vendor_id': str(vendor.id), 'shop_name': vendor.name, 'shop_type_id': str(vendor.shop_type_id)}


@router.get('/transactions')
def list_transactions(
    amount_gt: float | None = Query(default=None),
    start_date: str | None = Query(default=None),
    end_date: str | None = Query(default=None),
    vendor: str | None = Query(default=None),
    sort_by: str = Query(default='latest'),
    db: Session = Depends(get_db),
) -> list[dict]:
    stmt: Select[tuple[Transaction]] = select(Transaction)
    if amount_gt is not None:
        stmt = stmt.where(Transaction.amount > amount_gt)
    if vendor:
        stmt = stmt.where(Transaction.raw_vendor_name.ilike(f'%{vendor}%'))
    if start_date:
        stmt = stmt.where(Transaction.tx_timestamp >= datetime.fromisoformat(start_date))
    if end_date:
        stmt = stmt.where(Transaction.tx_timestamp <= datetime.fromisoformat(end_date))

    if sort_by == 'amount_asc':
        stmt = stmt.order_by(Transaction.amount.asc())
    elif sort_by == 'amount_desc':
        stmt = stmt.order_by(Transaction.amount.desc())
    elif sort_by == 'oldest':
        stmt = stmt.order_by(Transaction.tx_timestamp.asc())
    else:
        stmt = stmt.order_by(Transaction.tx_timestamp.desc())

    rows = db.scalars(stmt.limit(200)).all()
    return [
        {
            'id': str(tx.id),
            'amount': float(tx.amount),
            'type': tx.type,
            'raw_vendor_name': tx.raw_vendor_name,
            'description': tx.description,
        }
        for tx in rows
    ]
