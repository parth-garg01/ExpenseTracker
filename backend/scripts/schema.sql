CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY,
    email TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS shop_types (
    id UUID PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS vendors (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    normalized_name TEXT UNIQUE NOT NULL,
    shop_type_id UUID REFERENCES shop_types(id)
);

CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    amount NUMERIC(12,2) NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('debit','credit')),
    vendor_id UUID REFERENCES vendors(id),
    raw_vendor_name TEXT NOT NULL,
    tx_timestamp TIMESTAMPTZ NOT NULL,
    upi_reference TEXT,
    description TEXT
);

CREATE INDEX IF NOT EXISTS idx_transactions_user_time ON transactions(user_id, tx_timestamp DESC);
