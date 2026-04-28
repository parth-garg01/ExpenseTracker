from datetime import datetime
import uuid

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy import Select, select
from sqlalchemy.orm import Session

from app.api.schemas import SmsIngestRequest, SyncPushRequest, VendorClassifyRequest
from app.db.deps import get_db
from app.db.models import Transaction
from app.services.transactions import create_or_update_vendor, ingest_sms_transaction

router = APIRouter(prefix='/api')


@router.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok'}


def _require_user(user_id: str | None) -> str:
    if not user_id:
        raise HTTPException(status_code=401, detail='Missing X-User-Id header')
    return user_id


@router.post('/sync/push')
def sync_push(
    payload: SyncPushRequest,
    x_user_id: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> dict:
    user_id = _require_user(x_user_id)
    updated = 0
    inserted = 0

    for item in payload.transactions:
        if item.user_id != user_id:
            continue
        existing = db.scalar(select(Transaction).where(Transaction.id == uuid.UUID(item.id)))
        incoming_updated = datetime.fromisoformat(item.updated_at.replace('Z', '+00:00'))

        if existing is None:
            tx = Transaction(
                id=uuid.UUID(item.id),
                user_id=uuid.UUID(user_id),
                amount=item.amount,
                type=item.type,
                raw_vendor_name=item.raw_vendor_name,
                vendor_name=item.vendor_name,
                shop_type=item.shop_type,
                tx_timestamp=datetime.fromisoformat(item.tx_timestamp.replace('Z', '+00:00')),
                description=item.description,
                is_synced=True,
                updated_at=incoming_updated,
            )
            db.add(tx)
            inserted += 1
            continue

        if incoming_updated > existing.updated_at:
            existing.amount = item.amount
            existing.type = item.type
            existing.raw_vendor_name = item.raw_vendor_name
            existing.vendor_name = item.vendor_name
            existing.shop_type = item.shop_type
            existing.tx_timestamp = datetime.fromisoformat(item.tx_timestamp.replace('Z', '+00:00'))
            existing.description = item.description
            existing.updated_at = incoming_updated
            existing.is_synced = True
            updated += 1

    db.commit()
    return {'inserted': inserted, 'updated': updated}


@router.get('/sync/pull')
def sync_pull(
    since: str | None = Query(default=None),
    x_user_id: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> dict:
    user_id = _require_user(x_user_id)
    stmt = select(Transaction).where(Transaction.user_id == uuid.UUID(user_id))
    if since:
        since_dt = datetime.fromisoformat(since.replace('Z', '+00:00'))
        stmt = stmt.where(Transaction.updated_at > since_dt)
    rows = db.scalars(stmt.order_by(Transaction.updated_at.asc()).limit(1000)).all()
    return {
        'transactions': [
            {
                'id': str(tx.id),
                'user_id': str(tx.user_id),
                'amount': float(tx.amount),
                'type': tx.type,
                'raw_vendor_name': tx.raw_vendor_name,
                'vendor_name': tx.vendor_name,
                'shop_type': tx.shop_type,
                'tx_timestamp': tx.tx_timestamp.isoformat(),
                'description': tx.description,
                'is_synced': 1,
                'updated_at': tx.updated_at.isoformat(),
            }
            for tx in rows
        ]
    }


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
