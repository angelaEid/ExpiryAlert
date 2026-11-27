USE expiryalert;

CREATE USER 'expiry_final_app'@'127.0.0.1'
    IDENTIFIED BY 'REPLACE_WITH_APP_PASSWORD';

CREATE USER 'expiry_final_reader'@'127.0.0.1'
    IDENTIFIED BY 'REPLACE_WITH_READER_PASSWORD';

GRANT SELECT ON expiryalert.*
    TO 'expiry_final_app'@'127.0.0.1';

GRANT INSERT ON expiryalert.food_product
    TO 'expiry_final_app'@'127.0.0.1';

GRANT INSERT ON expiryalert.supplier_product
    TO 'expiry_final_app'@'127.0.0.1';

GRANT UPDATE (storage_id, expiration_date), DELETE ON expiryalert.inventory_batch
    TO 'expiry_final_app'@'127.0.0.1';

GRANT EXECUTE ON PROCEDURE expiryalert.create_purchase
    TO 'expiry_final_app'@'127.0.0.1';

GRANT EXECUTE ON PROCEDURE expiryalert.receive_batch
    TO 'expiry_final_app'@'127.0.0.1';

GRANT EXECUTE ON PROCEDURE expiryalert.record_movement
    TO 'expiry_final_app'@'127.0.0.1';

GRANT EXECUTE ON PROCEDURE expiryalert.record_food_waste
    TO 'expiry_final_app'@'127.0.0.1';

GRANT EXECUTE ON PROCEDURE expiryalert.refresh_alerts
    TO 'expiry_final_app'@'127.0.0.1';

GRANT EXECUTE ON PROCEDURE expiryalert.acknowledge_alert
    TO 'expiry_final_app'@'127.0.0.1';

GRANT SELECT ON expiryalert.v_waste_report
    TO 'expiry_final_reader'@'127.0.0.1';

-- Demonstrate adding and then removing access to the purchase view.
GRANT SELECT ON expiryalert.v_purchase_totals
    TO 'expiry_final_reader'@'127.0.0.1';

REVOKE SELECT ON expiryalert.v_purchase_totals
    FROM 'expiry_final_reader'@'127.0.0.1';

SHOW GRANTS FOR 'expiry_final_app'@'127.0.0.1';
SHOW GRANTS FOR 'expiry_final_reader'@'127.0.0.1';