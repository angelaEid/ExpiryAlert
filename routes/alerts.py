
from flask import (
    Blueprint,
    render_template,
    jsonify,
    current_app
)

from db import get_db_connection


alerts_bp = Blueprint("alerts", __name__)


@alerts_bp.route("/alerts")
def alerts():
    connection = None

    try:
        connection = get_db_connection()

        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT
                    ea.alert_id,
                    ea.batch_id,
                    fp.product_name,
                    ib.expiration_date,

                    DATEDIFF(
                        ib.expiration_date,
                        CURDATE()
                    ) AS days_until_expiration,

                    ea.alert_date,
                    ea.alert_type,
                    ea.notification_status

                FROM expiration_alert ea

                JOIN inventory_batch ib
                    ON ea.batch_id = ib.batch_id

                JOIN purchase_item pi
                    ON ib.purchase_item_id = pi.purchase_item_id

                JOIN food_product fp
                    ON pi.product_id = fp.product_id

                ORDER BY
                    ib.expiration_date ASC,
                    ea.alert_id ASC
            """)

            alerts_data = cursor.fetchall()

        return render_template(
            "alerts.html",
            alerts=alerts_data
        )

    except Exception:
        current_app.logger.exception(
            "Failed to retrieve expiration alerts"
        )

        return jsonify({
            "status": "error",
            "message": "Could not retrieve alerts."
        }), 500

    finally:
        if connection:
            connection.close()
