USE expiryalert;

-- Remove triggers from the original backup.
DROP TRIGGER IF EXISTS trg_validate_batch_storage;
DROP TRIGGER IF EXISTS trg_validate_purchase_item;

-- Allow this routines file to be reapplied after an edit.
DROP TRIGGER IF EXISTS trg_batch_insert;
DROP TRIGGER IF EXISTS trg_batch_update;
DROP TRIGGER IF EXISTS trg_purchase_item_insert;
DROP PROCEDURE IF EXISTS create_purchase;
DROP PROCEDURE IF EXISTS receive_batch;
DROP PROCEDURE IF EXISTS record_movement;
DROP PROCEDURE IF EXISTS record_food_waste;
DROP PROCEDURE IF EXISTS refresh_alerts;
DROP PROCEDURE IF EXISTS acknowledge_alert;
DROP FUNCTION IF EXISTS purchase_total;

DELIMITER //

CREATE TRIGGER trg_batch_insert
BEFORE INSERT ON inventory_batch
FOR EACH ROW
BEGIN
    DECLARE purchased_on DATE;
    DECLARE purchase_branch INT;
    DECLARE storage_branch INT;

    SELECT p.purchase_date, p.branch_id
    INTO purchased_on, purchase_branch
    FROM purchase_item AS pi
    JOIN purchase AS p USING (purchase_id)
    WHERE pi.purchase_item_id = NEW.purchase_item_id;

    SELECT branch_id INTO storage_branch
    FROM storage_location
    WHERE storage_id = NEW.storage_id;

    IF purchase_branch IS NULL OR storage_branch IS NULL
       OR purchase_branch <> storage_branch THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Storage must belong to the purchase branch';
    END IF;

    IF NEW.received_date < purchased_on THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Received date precedes purchase date';
    END IF;

    IF NEW.remaining_quantity <> NEW.initial_quantity THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A new batch must start with its initial quantity';
    END IF;

    SET NEW.batch_status = 'available';
END//

CREATE TRIGGER trg_batch_update
BEFORE UPDATE ON inventory_batch
FOR EACH ROW
BEGIN
    IF NEW.purchase_item_id <> OLD.purchase_item_id
       OR NEW.initial_quantity <> OLD.initial_quantity
       OR NEW.received_date <> OLD.received_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Original receipt details cannot be edited';
    END IF;

    IF NEW.storage_id <> OLD.storage_id AND NOT EXISTS (
        SELECT 1
        FROM purchase_item AS pi
        JOIN purchase AS p USING (purchase_id)
        JOIN storage_location AS sl ON sl.branch_id = p.branch_id
        WHERE pi.purchase_item_id = NEW.purchase_item_id
          AND sl.storage_id = NEW.storage_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Storage must belong to the purchase branch';
    END IF;

    SET NEW.batch_status = IF(NEW.remaining_quantity = 0, 'depleted', 'available');
END//

CREATE TRIGGER trg_purchase_item_insert
BEFORE INSERT ON purchase_item
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM purchase AS p
        JOIN supplier_product AS sp USING (supplier_id)
        WHERE p.purchase_id = NEW.purchase_id
          AND sp.product_id = NEW.product_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Supplier does not offer this product';
    END IF;
END//

CREATE FUNCTION purchase_total(p_purchase_id INT)
RETURNS DECIMAL(28,4)
READS SQL DATA
RETURN (
    SELECT COALESCE(SUM(quantity * unit_cost), 0)
    FROM purchase_item
    WHERE purchase_id = p_purchase_id
)//

CREATE PROCEDURE create_purchase(
    IN p_branch INT,
    IN p_supplier INT,
    IN p_date DATE,
    IN p_items JSON
)
BEGIN
    DECLARE purchase_key INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_items IS NULL OR JSON_TYPE(p_items) <> 'ARRAY' OR JSON_LENGTH(p_items) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A purchase needs at least one item';
    END IF;

    START TRANSACTION;

    INSERT INTO purchase (branch_id, supplier_id, purchase_date)
    VALUES (p_branch, p_supplier, p_date);

    SET purchase_key = LAST_INSERT_ID();

    INSERT INTO purchase_item (purchase_id, product_id, quantity, unit_cost)
    SELECT purchase_key, line.product_id, line.quantity, line.unit_cost
    FROM JSON_TABLE(p_items, '$[*]' COLUMNS (
        product_id INT PATH '$.product_id' ERROR ON EMPTY ERROR ON ERROR,
        quantity DECIMAL(10,2) PATH '$.quantity' ERROR ON EMPTY ERROR ON ERROR,
        unit_cost DECIMAL(10,2) PATH '$.unit_cost' ERROR ON EMPTY ERROR ON ERROR
    )) AS line;

    COMMIT;
END//

CREATE PROCEDURE receive_batch(
    IN p_item INT,
    IN p_storage INT,
    IN p_received DATE,
    IN p_expiration DATE,
    IN p_quantity DECIMAL(10,2)
)
BEGIN
    DECLARE purchased DECIMAL(10,2);
    DECLARE allocated DECIMAL(20,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Receipts for the same purchase line acquire this lock first.
    SELECT quantity INTO purchased
    FROM purchase_item
    WHERE purchase_item_id = p_item
    FOR UPDATE;

    SELECT COALESCE(SUM(initial_quantity), 0) INTO allocated
    FROM inventory_batch
    WHERE purchase_item_id = p_item
    FOR UPDATE;

    IF purchased IS NULL OR p_quantity IS NULL OR p_quantity <= 0
       OR allocated + p_quantity > purchased THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid receipt or quantity above unreceived stock';
    END IF;

    INSERT INTO inventory_batch
        (purchase_item_id, storage_id, received_date, expiration_date,
         initial_quantity, remaining_quantity)
    VALUES
        (p_item, p_storage, p_received, p_expiration, p_quantity, p_quantity);

    COMMIT;
END//

CREATE PROCEDURE record_movement(
    IN p_batch INT,
    IN p_employee INT,
    IN p_type VARCHAR(20),
    IN p_quantity DECIMAL(10,2),
    IN p_notes TEXT
)
BEGIN
    DECLARE current_qty DECIMAL(10,2);
    DECLARE initial_qty DECIMAL(10,2);
    DECLARE updated_qty DECIMAL(11,2);
    DECLARE batch_branch INT;
    DECLARE employee_branch INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_type IS NULL OR p_type NOT IN ('usage', 'adjust_in', 'adjust_out')
       OR p_quantity IS NULL OR p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid movement type or quantity';
    END IF;

    START TRANSACTION;

    SELECT ib.remaining_quantity, ib.initial_quantity, p.branch_id
    INTO current_qty, initial_qty, batch_branch
    FROM inventory_batch AS ib
    JOIN purchase_item AS pi USING (purchase_item_id)
    JOIN purchase AS p USING (purchase_id)
    WHERE ib.batch_id = p_batch
    FOR UPDATE;

    SELECT branch_id INTO employee_branch
    FROM employee
    WHERE employee_id = p_employee
    FOR UPDATE;

    IF batch_branch IS NULL OR employee_branch IS NULL OR employee_branch <> batch_branch THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Select an employee from the batch branch';
    END IF;

    SET updated_qty = current_qty + IF(p_type = 'adjust_in', p_quantity, -p_quantity);

    IF updated_qty < 0 OR updated_qty > initial_qty THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Movement would exceed stock bounds';
    END IF;

    UPDATE inventory_batch
    SET remaining_quantity = updated_qty
    WHERE batch_id = p_batch;

    INSERT INTO inventory_movement
        (batch_id, employee_id, movement_type, quantity, movement_date, notes)
    VALUES
        (p_batch, p_employee, p_type, p_quantity, CURRENT_TIMESTAMP, p_notes);

    COMMIT;
END//

CREATE PROCEDURE record_food_waste(
    IN p_batch_id INT,
    IN p_employee_id INT,
    IN p_quantity DECIMAL(10,2),
    IN p_reason VARCHAR(255)
)
BEGIN
    DECLARE v_remaining DECIMAL(10,2);
    DECLARE v_unit_cost DECIMAL(10,2);
    DECLARE v_batch_branch INT;
    DECLARE v_employee_branch INT;
    DECLARE v_missing BOOLEAN DEFAULT FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_missing = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_quantity IS NULL OR p_quantity <= 0
       OR p_reason IS NULL OR TRIM(p_reason) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Enter a positive quantity and a disposal reason';
    END IF;

    START TRANSACTION;

    SELECT ib.remaining_quantity, pi.unit_cost, p.branch_id
    INTO v_remaining, v_unit_cost, v_batch_branch
    FROM inventory_batch AS ib
    JOIN purchase_item AS pi USING (purchase_item_id)
    JOIN purchase AS p USING (purchase_id)
    WHERE ib.batch_id = p_batch_id
    FOR UPDATE;

    IF v_missing THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Inventory batch not found';
    END IF;

    SELECT branch_id INTO v_employee_branch
    FROM employee
    WHERE employee_id = p_employee_id
    FOR UPDATE;

    IF v_missing THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Employee not found';
    END IF;

    IF v_employee_branch <> v_batch_branch THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Employee belongs to another branch';
    END IF;

    IF p_quantity > v_remaining THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient inventory quantity';
    END IF;

    UPDATE inventory_batch
    SET remaining_quantity = v_remaining - p_quantity
    WHERE batch_id = p_batch_id;

    INSERT INTO food_waste
        (batch_id, employee_id, discarded_quantity, disposal_reason,
         disposal_date, estimated_loss)
    VALUES
        (p_batch_id, p_employee_id, p_quantity, p_reason,
         CURRENT_DATE, p_quantity * v_unit_cost);

    COMMIT;
END//

CREATE PROCEDURE refresh_alerts()
BEGIN
    INSERT INTO expiration_alert (batch_id, alert_date, alert_type)
    SELECT v.batch_id, CURRENT_DATE, v.expiration_status
    FROM v_batch_details AS v
    WHERE v.expiration_status IN ('Expired', 'Approaching Expiration')
    ON DUPLICATE KEY UPDATE alert_id = expiration_alert.alert_id;
END//

CREATE PROCEDURE acknowledge_alert(IN p_alert INT)
BEGIN
    UPDATE expiration_alert
    SET notification_status = 'acknowledged'
    WHERE alert_id = p_alert AND notification_status = 'pending';
END//

DELIMITER ;