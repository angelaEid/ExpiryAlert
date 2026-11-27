from datetime import date
import json

from flask import Blueprint, abort, flash, redirect, render_template, request, url_for

from db import fetch_all, write
from validation import date_field, id_field, parse_id, quantity, quantity_field, text_field

operations_bp = Blueprint("operations", __name__)


def branch_options():
    return fetch_all("SELECT branch_id, branch_name FROM branch ORDER BY branch_name")


def supplier_options():
    return fetch_all("SELECT supplier_id, supplier_name FROM supplier ORDER BY supplier_name")


@operations_bp.route("/products", methods=["GET", "POST"])
def products():
    if request.method == "POST":
        try:
            if request.form.get("action") == "link":
                saved = write(
                    "INSERT INTO supplier_product (supplier_id, product_id) VALUES (%s, %s)",
                    (id_field("supplier_id"), id_field("product_id")),
                )
            else:
                days = request.form.get("days", type=int)
                if days is None or not 0 <= days <= 36500:
                    raise ValueError("Enter an alert threshold from 0 to 36500 days.")

                saved = write("""
                    INSERT INTO food_product
                        (category_id, product_name, description, measurement_unit,
                         storage_requirements, reorder_level, expiration_alert_days)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                """, (
                    id_field("category_id"),
                    text_field("product_name", 100),
                    text_field("description", 2000, False) or None,
                    text_field("measurement_unit", 30),
                    text_field("storage_requirements", 255, False) or None,
                    quantity_field("reorder_level", True),
                    days,
                ))

            if saved:
                flash("Catalog updated.", "success")
                return redirect(url_for("operations.products"))
        except ValueError as exc:
            flash(str(exc), "error")

    rows = fetch_all("""
        SELECT product_id, product_name, category_name, measurement_unit,
               reorder_level, expiration_alert_days
        FROM food_product JOIN product_category USING (category_id)
        ORDER BY product_name
    """)
    categories = fetch_all("""
        SELECT category_id, category_name
        FROM product_category ORDER BY category_name
    """)
    return render_template(
        "operations.html", section="products", title="Products",
        rows=rows, categories=categories, suppliers=supplier_options(),
    )


@operations_bp.route("/purchases", methods=["GET", "POST"])
def purchases():
    if request.method == "POST":
        try:
            lines = []
            fields = zip(
                request.form.getlist("product_id"),
                request.form.getlist("quantity"),
                request.form.getlist("unit_cost"),
                strict=True,
            )

            for product, amount, cost in fields:
                if not (product or amount or cost):
                    continue
                lines.append({
                    "product_id": parse_id(product),
                    "quantity": str(quantity(amount)),
                    "unit_cost": str(quantity(cost, True)),
                })

            if not 1 <= len(lines) <= 5:
                raise ValueError("Enter between one and five purchase lines.")

            if write("CALL create_purchase(%s, %s, %s, %s)", (
                id_field("branch_id"),
                id_field("supplier_id"),
                date_field("purchase_date"),
                json.dumps(lines),
            )):
                flash("Purchase saved. Receive it from Add Inventory Batch.", "success")
                return redirect(url_for("operations.purchases"))
        except ValueError as exc:
            flash(str(exc), "error")

    offers = fetch_all("""
        SELECT fp.product_id,
               CONCAT(s.supplier_name, ' / ', fp.product_name) AS label
        FROM supplier_product sp JOIN supplier s USING (supplier_id)
        JOIN food_product fp USING (product_id)
        ORDER BY s.supplier_name, fp.product_name
    """)
    rows = fetch_all("""
        SELECT purchase_id, branch_name, supplier_name, purchase_date, item_count, total_cost
        FROM v_purchase_totals ORDER BY purchase_id DESC
    """)
    return render_template(
        "operations.html", section="purchases", title="Purchases",
        rows=rows, branches=branch_options(), suppliers=supplier_options(),
        offers=offers, today=date.today().isoformat(),
    )


@operations_bp.route("/inventory/<int:batch_id>/activity", methods=["GET", "POST"])
def activity(batch_id):
    rows = fetch_all(
        "SELECT * FROM v_batch_details WHERE batch_id = %s", (batch_id,)
    )
    if not rows:
        abort(404)
    batch = rows[0]

    if request.method == "POST":
        try:
            action = request.form.get("action")
            employee = id_field("employee_id")
            amount = quantity_field("quantity")
            notes = text_field("notes", 255, required=(action == "waste"))

            if action == "waste":
                saved = write(
                    "CALL record_food_waste(%s, %s, %s, %s)",
                    (batch_id, employee, amount, notes),
                )
            elif action in {"usage", "adjust_in", "adjust_out"}:
                saved = write(
                    "CALL record_movement(%s, %s, %s, %s, %s)",
                    (batch_id, employee, action, amount, notes or None),
                )
            else:
                raise ValueError("Choose a stock action.")

            if saved:
                flash("Stock activity recorded.", "success")
                return redirect(url_for("operations.activity", batch_id=batch_id))
        except ValueError as exc:
            flash(str(exc), "error")

    employees = fetch_all("""
        SELECT employee_id, full_name FROM employee
        WHERE branch_id = %s ORDER BY full_name
    """, (batch["branch_id"],))
    movements = fetch_all("""
        SELECT movement_date, full_name, movement_type, quantity, notes
        FROM inventory_movement JOIN employee USING (employee_id)
        WHERE batch_id = %s ORDER BY movement_id DESC
    """, (batch_id,))
    waste = fetch_all("""
        SELECT disposal_date, full_name, discarded_quantity, disposal_reason, estimated_loss
        FROM food_waste JOIN employee USING (employee_id)
        WHERE batch_id = %s ORDER BY waste_id DESC
    """, (batch_id,))
    return render_template(
        "operations.html", section="activity", title="Stock Activity",
        batch=batch, employees=employees, movements=movements, waste=waste,
    )


@operations_bp.get("/reports")
def reports():
    branch = request.args.get("branch", 0, type=int)
    stock = fetch_all("""
        SELECT branch_name, product_name, stock_quantity, usable_quantity,
               reorder_level, measurement_unit
        FROM v_branch_stock
        WHERE stock_quantity < reorder_level AND (%s = 0 OR branch_id = %s)
        ORDER BY branch_name, product_name
    """, (branch, branch))
    waste = fetch_all("""
        SELECT branch_name, product_name, disposal_reason, records,
               discarded, measurement_unit, total_loss
        FROM v_waste_report
        WHERE (%s = 0 OR branch_id = %s)
        ORDER BY total_loss DESC
    """, (branch, branch))
    return render_template(
        "operations.html", section="reports", title="Reports",
        branches=branch_options(), branch=branch, stock=stock, waste=waste,
    )