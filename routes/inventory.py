from datetime import date

from flask import Blueprint, abort, flash, redirect, render_template, request, url_for

from db import fetch_all, write
from validation import date_field, id_field, quantity_field

inventory_bp = Blueprint("inventory", __name__)


@inventory_bp.get("/inventory")
def inventory():
    branch = request.args.get("branch", 0, type=int)
    search = request.args.get("q", "").strip()[:100]

    rows = fetch_all("""
        SELECT *
        FROM v_batch_details
        WHERE (%s = 0 OR branch_id = %s)
          AND (%s = '' OR LOCATE(%s, product_name) > 0)
        ORDER BY expiration_date, batch_id
    """, (branch, branch, search, search))

    branches = fetch_all("""
        SELECT branch_id, branch_name
        FROM branch
        ORDER BY branch_name
    """)

    return render_template(
        "inventory.html",
        inventory=rows,
        branches=branches,
        branch=branch,
        search=search,
    )


@inventory_bp.route("/inventory/add", methods=["GET", "POST"])
def add_batch():
    if request.method == "POST":
        try:
            args = (
                id_field("purchase_item_id"),
                id_field("storage_id"),
                date_field("received_date"),
                date_field("expiration_date"),
                quantity_field("initial_quantity"),
            )
            if args[3] < args[2]:
                raise ValueError("Expiration date cannot be before the received date.")

            if write("CALL receive_batch(%s, %s, %s, %s, %s)", args):
                flash("Inventory batch received.", "success")
                return redirect(url_for("inventory.inventory"))
        except ValueError as exc:
            flash(str(exc), "error")

    purchase_items = fetch_all("""
        SELECT pi.purchase_item_id, fp.product_name, fp.measurement_unit,
               b.branch_name,
               pi.quantity - COALESCE(SUM(ib.initial_quantity), 0) AS unreceived
        FROM purchase_item AS pi
        JOIN food_product AS fp USING (product_id)
        JOIN purchase AS p USING (purchase_id)
        JOIN branch AS b USING (branch_id)
        LEFT JOIN inventory_batch AS ib USING (purchase_item_id)
        GROUP BY pi.purchase_item_id, pi.quantity, fp.product_name,
                 fp.measurement_unit, b.branch_name
        HAVING pi.quantity > COALESCE(SUM(ib.initial_quantity), 0)
        ORDER BY pi.purchase_item_id DESC
    """)

    locations = fetch_all("""
        SELECT sl.storage_id, sl.storage_name, b.branch_name
        FROM storage_location AS sl
        JOIN branch AS b USING (branch_id)
        ORDER BY b.branch_name, sl.storage_name
    """)

    return render_template(
        "add_batch.html",
        purchase_items=purchase_items,
        storage_locations=locations,
        today=date.today().isoformat(),
    )


@inventory_bp.route("/inventory/edit/<int:batch_id>", methods=["GET", "POST"])
def edit_batch(batch_id):
    rows = fetch_all(
        "SELECT * FROM v_batch_details WHERE batch_id = %s",
        (batch_id,),
    )
    if not rows:
        abort(404)

    batch = rows[0]

    if request.method == "POST":
        try:
            storage_id = id_field("storage_id")
            expiration = date_field("expiration_date")
            if expiration < batch["received_date"]:
                raise ValueError("Expiration date cannot be before the received date.")

            if write("""
                UPDATE inventory_batch
                SET storage_id = %s, expiration_date = %s
                WHERE batch_id = %s
            """, (storage_id, expiration, batch_id)):
                flash("Batch details updated.", "success")
                return redirect(url_for("inventory.inventory"))
        except ValueError as exc:
            flash(str(exc), "error")

    locations = fetch_all("""
        SELECT storage_id, storage_name
        FROM storage_location
        WHERE branch_id = %s
        ORDER BY storage_name
    """, (batch["branch_id"],))

    return render_template(
        "edit_batch.html",
        batch=batch,
        storage_locations=locations,
    )


@inventory_bp.post("/inventory/delete/<int:batch_id>")
def delete_batch(batch_id):
    rows = fetch_all(
        "SELECT batch_id FROM inventory_batch WHERE batch_id = %s",
        (batch_id,),
    )
    if not rows:
        abort(404)

    if write("DELETE FROM inventory_batch WHERE batch_id = %s", (batch_id,)):
        flash("Batch deleted.", "success")

    return redirect(url_for("inventory.inventory"))