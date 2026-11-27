from datetime import date
from decimal import Decimal, InvalidOperation

from flask import request


def parse_id(value):
    try:
        number = int(value)
    except (TypeError, ValueError):
        raise ValueError("Choose a valid record.") from None

    if not 0 < number <= 2147483647:
        raise ValueError("Choose a valid record.")

    return number


def id_field(name):
    return parse_id(request.form.get(name, ""))


def date_field(name):
    value = request.form.get(name, "").strip()

    try:
        return date.fromisoformat(value)
    except ValueError:
        label = name.replace("_", " ")
        raise ValueError(f"Enter a valid {label}.") from None


def quantity(value, zero_allowed=False):
    try:
        amount = Decimal(value)
    except (InvalidOperation, TypeError, ValueError):
        raise ValueError("Enter a valid quantity or price.") from None

    if (
        not amount.is_finite()
        or amount < 0
        or amount > Decimal("99999999.99")
        or (amount == 0 and not zero_allowed)
        or amount.as_tuple().exponent < -2
    ):
        raise ValueError("Enter a number in range with at most two decimal places.")

    return amount


def quantity_field(name, zero_allowed=False):
    return quantity(request.form.get(name, ""), zero_allowed)


def text_field(name, limit, required=True):
    value = request.form.get(name, "").strip()
    label = name.replace("_", " ").capitalize()

    if required and not value:
        raise ValueError(f"{label} is required.")
    if len(value) > limit:
        raise ValueError(f"{label} must be {limit} characters or fewer.")

    return value