from flask import Blueprint, flash, redirect, render_template, url_for

from db import fetch_all, write

alerts_bp = Blueprint("alerts", __name__)


@alerts_bp.get("/alerts")
def alerts():
    rows = fetch_all("""
        SELECT ea.alert_id, ea.batch_id, v.product_name, v.branch_name,
               v.expiration_date, v.expiration_status, ea.alert_type,
               ea.alert_date, ea.notification_status
        FROM expiration_alert AS ea
        JOIN v_batch_details AS v USING (batch_id)
        ORDER BY ea.alert_date DESC, ea.alert_id DESC
    """)
    return render_template("alerts.html", alerts=rows)


@alerts_bp.post("/alerts/refresh")
def refresh():
    if write("CALL refresh_alerts()"):
        flash("Alerts refreshed.", "success")
    return redirect(url_for("alerts.alerts"))


@alerts_bp.post("/alerts/<int:alert_id>/acknowledge")
def acknowledge(alert_id):
    if write("CALL acknowledge_alert(%s)", (alert_id,)):
        flash("Alert list updated.", "success")
    return redirect(url_for("alerts.alerts"))