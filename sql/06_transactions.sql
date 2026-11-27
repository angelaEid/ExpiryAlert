USE expiryalert;

-- COMMIT retains the temporary category.
START TRANSACTION;

INSERT INTO product_category (category_name, description)
VALUES ('Transaction demo', 'Temporary record for the COE 418 demo');

SET @demo_id = LAST_INSERT_ID();

COMMIT;

SELECT COUNT(*) AS expected_one_after_commit
FROM product_category
WHERE category_id = @demo_id;

-- ROLLBACK undoes the deletion. The category still exists.
START TRANSACTION;

DELETE FROM product_category
WHERE category_id = @demo_id;

ROLLBACK;

SELECT COUNT(*) AS expected_one_after_rollback
FROM product_category
WHERE category_id = @demo_id;

-- Remove the temporary record after both observations.
DELETE FROM product_category
WHERE category_id = @demo_id;

-- Expected on the supplied seed: 270.0000.
SELECT purchase_total(1) AS purchase_1_total;

-- Composite index supports branch equality and a purchase-date range.
EXPLAIN
SELECT purchase_id
FROM purchase
WHERE branch_id = 1
  AND purchase_date >= CURRENT_DATE - INTERVAL 30 DAY
ORDER BY purchase_date;

-- Expiration index supports date-range filtering.
EXPLAIN
SELECT batch_id
FROM inventory_batch
WHERE expiration_date < CURRENT_DATE;

-- Disposal index supports a reporting date range.
EXPLAIN
SELECT SUM(estimated_loss)
FROM food_waste
WHERE disposal_date >= CURRENT_DATE - INTERVAL 30 DAY;