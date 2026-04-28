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
