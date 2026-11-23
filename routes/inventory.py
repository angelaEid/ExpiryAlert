from flask import render_template, request, redirect, url_for, flash
from datetime import date
from decimal import Decimal, InvalidOperation
from db import get_db_connection
from flask import (
    Blueprint,
    render_template,
    jsonify,
    current_app
)

inventory_bp = Blueprint("inventory", __name__)


@inventory_bp.route("/inventory")
def inventory():
    connection = None

    try:
        connection = get_db_connection()

        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT
                    ib.batch_id,
                    fp.product_name,
                    ib.received_date,
                    ib.expiration_date,
                    ib.initial_quantity,
                    ib.remaining_quantity,
                    ib.batch_status,
                    fp.expiration_alert_days,

                    DATEDIFF(
                        ib.expiration_date,
                        CURDATE()
                    ) AS days_until_expiration,

                    CASE
                        WHEN ib.expiration_date < CURDATE()
                            THEN 'Expired'

                        WHEN DATEDIFF(
                            ib.expiration_date,
                            CURDATE()
                        ) <= fp.expiration_alert_days
                            THEN 'Approaching Expiration'

                        ELSE 'Safe'
                    END AS expiration_status

                FROM inventory_batch ib

                JOIN purchase_item pi
                    ON ib.purchase_item_id = pi.purchase_item_id

                JOIN food_product fp
                    ON pi.product_id = fp.product_id

                ORDER BY ib.expiration_date
            """)

            inventory_data = cursor.fetchall()

        return render_template(
            "inventory.html",
            inventory=inventory_data
        )

    except Exception:
        current_app.logger.exception(
            "Failed to retrieve inventory"
        )

        return jsonify({
            "status": "error",
            "message": "Could not retrieve inventory."
        }), 500

    finally:
        if connection:
            connection.close()


@inventory_bp.route("/inventory/add", methods=["GET", "POST"])
def add_batch():
    connection = None

    try:
        connection = get_db_connection()

        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT
                    pi.purchase_item_id,
                    fp.product_name,
                    pi.quantity
                FROM purchase_item pi
                JOIN food_product fp
                    ON pi.product_id = fp.product_id
                ORDER BY fp.product_name, pi.purchase_item_id
            """)
            purchase_items = cursor.fetchall()

            cursor.execute("""
                SELECT
                    storage_id,
                    storage_name,
                    storage_type
                FROM storage_location
                ORDER BY storage_name
            """)
            storage_locations = cursor.fetchall()

        if request.method == "POST":
            purchase_item_id = request.form.get(
                "purchase_item_id", type=int
            )
            storage_id = request.form.get(
                "storage_id", type=int
            )
            received_date = request.form.get("received_date")
            expiration_date = request.form.get("expiration_date")
            quantity_text = request.form.get("initial_quantity", "")

            try:
                quantity = Decimal(quantity_text)
            except (InvalidOperation, ValueError):
                quantity = Decimal("0")

            if not purchase_item_id or not storage_id:
                flash("Please select a purchase item and storage location.", "error")

            elif not received_date or not expiration_date:
                flash("Please enter both dates.", "error")

            elif expiration_date < received_date:
                flash("Expiration date cannot be before received date.", "error")

            elif not quantity.is_finite() or quantity <= 0 or quantity > Decimal("99999999.99") or quantity.as_tuple().exponent < -2:
                flash("Enter a valid positive quantity with at most 2 decimal places.", "error")

            else:
                valid_purchase = any(
                    item["purchase_item_id"] == purchase_item_id
                    for item in purchase_items
                )

                valid_storage = any(
                    item["storage_id"] == storage_id
                    for item in storage_locations
                )

                if not valid_purchase or not valid_storage:
                    flash("Invalid purchase item or storage location.", "error")

                else:
                    with connection.cursor() as cursor:
                        cursor.execute("""
                            INSERT INTO inventory_batch (
                                purchase_item_id,
                                storage_id,
                                received_date,
                                expiration_date,
                                initial_quantity,
                                remaining_quantity,
                                batch_status
                            )
                            VALUES (%s, %s, %s, %s, %s, %s, %s)
                        """, (
                            purchase_item_id,
                            storage_id,
                            received_date,
                            expiration_date,
                            quantity,
                            quantity,
                            "available"
                        ))

                    connection.commit()
                    flash("Inventory batch added successfully!", "success")

                    return redirect(url_for("inventory.inventory"))

        return render_template(
            "add_batch.html",
            purchase_items=purchase_items,
            storage_locations=storage_locations,
            today=date.today().isoformat()
        )

    except Exception:
        if connection:
            connection.rollback()

        inventory_bp.logger.exception("Failed to add inventory batch") if hasattr(inventory_bp, "logger") else None
        from flask import current_app
        current_app.logger.exception("Failed to add inventory batch")
        return "Could not load or save inventory batch.", 500

    finally:
        if connection:
            connection.close()


@inventory_bp.route("/inventory/edit/<int:batch_id>", methods=["GET", "POST"])
def edit_batch(batch_id):
    connection = None

    try:
        connection = get_db_connection()

        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT
                    batch_id,
                    purchase_item_id,
                    storage_id,
                    received_date,
                    expiration_date,
                    initial_quantity,
                    remaining_quantity,
                    batch_status
                FROM inventory_batch
                WHERE batch_id = %s
            """, (batch_id,))

            batch = cursor.fetchone()

            if batch is None:
                return "Inventory batch not found.", 404

            cursor.execute("""
                SELECT storage_id, storage_name
                FROM storage_location
                ORDER BY storage_name
            """)

            storage_locations = cursor.fetchall()

        if request.method == "POST":
            storage_id = request.form.get("storage_id", type=int)
            expiration_text = request.form.get("expiration_date", "")
            quantity_text = request.form.get("remaining_quantity", "")

            try:
                expiration = date.fromisoformat(expiration_text)
                quantity = Decimal(quantity_text)
            except (ValueError, InvalidOperation):
                flash("Please enter valid dates and quantities.", "error")
                return redirect(url_for(
                    "inventory.edit_batch", batch_id=batch_id
                ))

            valid_storage = any(
                location["storage_id"] == storage_id
                for location in storage_locations
            )

            if not valid_storage:
                flash("Please select a valid storage location.", "error")

            elif expiration < batch["received_date"]:
                flash("Expiration date cannot be before received date.", "error")

            elif (
                not quantity.is_finite()
                or quantity < 0
                or quantity > batch["initial_quantity"]
                or quantity.as_tuple().exponent < -2
            ):
                flash("Remaining quantity must be between 0 and the initial quantity, with at most 2 decimal places.", "error")

            else:
                new_status = "available" if quantity > 0 else "depleted"

                with connection.cursor() as cursor:
                    cursor.execute("""
                        UPDATE inventory_batch
                        SET storage_id = %s,
                            expiration_date = %s,
                            remaining_quantity = %s,
                            batch_status = %s
                        WHERE batch_id = %s
                    """, (
                        storage_id,
                        expiration,
                        quantity,
                        new_status,
                        batch_id
                    ))

                connection.commit()

                flash("Inventory batch updated successfully!", "success")

                return redirect(url_for("inventory.inventory"))

        return render_template(
            "edit_batch.html",
            batch=batch,
            storage_locations=storage_locations
        )

    except Exception:
        if connection:
            connection.rollback()

        current_app.logger.exception("Failed to edit inventory batch")
        return "Could not edit inventory batch.", 500

    finally:
        if connection:
            connection.close()


@inventory_bp.route("/inventory/delete/<int:batch_id>", methods=["POST"])
def delete_batch(batch_id):
    connection = None

    try:
        connection = get_db_connection()

        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT batch_id
                FROM inventory_batch
                WHERE batch_id = %s
            """, (batch_id,))

            batch = cursor.fetchone()

            if not batch:
                flash("Inventory batch not found.", "error")
                return redirect(url_for("inventory.inventory"))

            cursor.execute("""
                DELETE FROM inventory_batch
                WHERE batch_id = %s
            """, (batch_id,))

        connection.commit()

        flash("Inventory batch deleted successfully!", "success")

    except Exception:
        if connection:
            connection.rollback()

        current_app.logger.exception(
            "Failed to delete inventory batch"
        )

        flash(
            "Could not delete inventory batch. It may be referenced by other records.",
            "error"
        )

    finally:
        if connection:
            connection.close()

    return redirect(url_for("inventory.inventory"))


