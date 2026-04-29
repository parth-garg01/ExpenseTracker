from pydantic import BaseModel, Field


class SmsIngestRequest(BaseModel):
    user_id: str
    sms_body: str = Field(min_length=5)


class VendorClassifyRequest(BaseModel):
    raw_vendor_name: str
    shop_name: str
    shop_type_name: str


class TransactionEditRequest(BaseModel):
    shop_name: str | None = None
    shop_type_name: str | None = None
    description: str | None = None


class SyncTransaction(BaseModel):
    id: str
    user_id: str
    amount: float
    type: str
    raw_vendor_name: str
    vendor_name: str | None = None
    shop_type: str = 'Anonymous'
    tx_timestamp: str
    description: str | None = None
    is_synced: int | bool = 0
    updated_at: str


class SyncPushRequest(BaseModel):
    transactions: list[SyncTransaction]


class RegisterRequest(BaseModel):
    email: str
    password: str = Field(min_length=6)


class LoginRequest(BaseModel):
    email: str
    password: str
