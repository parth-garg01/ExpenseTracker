import re
from datetime import datetime, timezone

SMS_PATTERNS = [
    re.compile(
        r"(?:debited|spent)\s*(?:INR|Rs\.?|₹)?\s*(?P<amount>\d+(?:\.\d{1,2})?).*?(?:to|at)\s+(?P<vendor>[A-Za-z0-9 _\-.]+).*?(?:UPI|Ref|UTR)[:\s-]*(?P<upi>[A-Za-z0-9-]+)",
        re.IGNORECASE,
    ),
    re.compile(
        r"(?:credited|received)\s*(?:INR|Rs\.?|₹)?\s*(?P<amount>\d+(?:\.\d{1,2})?).*?(?:from)\s+(?P<vendor>[A-Za-z0-9 _\-.]+).*?(?:UPI|Ref|UTR)[:\s-]*(?P<upi>[A-Za-z0-9-]+)",
        re.IGNORECASE,
    ),
]


def parse_sms(message: str) -> dict:
    for pattern in SMS_PATTERNS:
        match = pattern.search(message)
        if match:
            tx_type = 'debit' if 'debit' in pattern.pattern or 'spent' in pattern.pattern else 'credit'
            return {
                'amount': float(match.group('amount')),
                'type': tx_type,
                'raw_vendor_name': match.group('vendor').strip(),
                'upi_reference': match.group('upi').strip(),
                'tx_timestamp': datetime.now(timezone.utc),
                'raw_sms': message,
            }

    amount_match = re.search(r'(?:INR|Rs\.?|₹)\s*(\d+(?:\.\d{1,2})?)', message, re.IGNORECASE)
    if not amount_match:
        raise ValueError('Unable to parse transaction amount from SMS')

    return {
        'amount': float(amount_match.group(1)),
        'type': 'debit' if re.search(r'debited|spent|paid', message, re.IGNORECASE) else 'credit',
        'raw_vendor_name': 'UNKNOWN',
        'upi_reference': None,
        'tx_timestamp': datetime.now(timezone.utc),
        'raw_sms': message,
    }


def normalize_vendor_name(name: str) -> str:
    cleaned = re.sub(r'[^A-Za-z0-9 ]+', ' ', name).strip().lower()
    return re.sub(r'\s+', ' ', cleaned)
