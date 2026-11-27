USE expiryalert;

-- 1. INNER JOIN: identify the product and owner branch for each batch.
SELECT ib.batch_id, fp.product_name, b.branch_name
FROM inventory_batch AS ib
JOIN purchase_item AS pi USING (purchase_item_id)
JOIN food_product AS fp USING (product_id)
JOIN purchase AS p USING (purchase_id)
JOIN branch AS b USING (branch_id)
ORDER BY ib.batch_id;

-- 2. LEFT JOIN: include employees who have no waste records.
SELECT e.employee_id, e.full_name, COUNT(w.waste_id) AS waste_records
FROM employee AS e
LEFT JOIN food_waste AS w USING (employee_id)
GROUP BY e.employee_id, e.full_name
ORDER BY e.employee_id;

-- 3. SELF JOIN: pair batches from the same purchase line.
SELECT a.purchase_item_id, a.batch_id AS first_batch, b.batch_id AS second_batch
FROM inventory_batch AS a
JOIN inventory_batch AS b
    ON b.purchase_item_id = a.purchase_item_id AND b.batch_id > a.batch_id
ORDER BY a.purchase_item_id, a.batch_id, b.batch_id;

-- 4. GROUP BY and HAVING: find purchase lines received in several batches.
SELECT purchase_item_id, COUNT(*) AS batch_count
FROM inventory_batch
GROUP BY purchase_item_id
HAVING COUNT(*) > 1;

-- 5. UNION: employees who recorded a movement or a disposal.
SELECT employee_id FROM inventory_movement
UNION
SELECT employee_id FROM food_waste;

-- 6. Nested IN: suppliers whose purchased stock produced a waste record.
SELECT supplier_id, supplier_name
FROM supplier
WHERE supplier_id IN (
    SELECT supplier_id
    FROM purchase
    WHERE purchase_id IN (
        SELECT pi.purchase_id
        FROM purchase_item AS pi
        JOIN inventory_batch AS ib USING (purchase_item_id)
        JOIN food_waste AS w USING (batch_id)
    )
);

-- 7. Correlated subquery: purchase lines above their product's average price.
SELECT pi.purchase_item_id, pi.product_id, pi.unit_cost
FROM purchase_item AS pi
WHERE pi.unit_cost > (
    SELECT AVG(other.unit_cost)
    FROM purchase_item AS other
    WHERE other.product_id = pi.product_id
);

-- 8. NOT IN: employees with no recorded movements.
-- inventory_movement.employee_id is NOT NULL.
SELECT employee_id, full_name
FROM employee
WHERE employee_id NOT IN (
    SELECT employee_id FROM inventory_movement
);

-- 9. EXISTS: branches with stock that has expired or expires within three days.
SELECT b.branch_id, b.branch_name
FROM branch AS b
WHERE EXISTS (
    SELECT 1
    FROM storage_location AS sl
    JOIN inventory_batch AS ib USING (storage_id)
    WHERE sl.branch_id = b.branch_id
      AND ib.remaining_quantity > 0
      AND ib.expiration_date <= CURRENT_DATE + INTERVAL 3 DAY
);

-- 10. Relational division: suppliers offering every Dairy product.
SELECT s.supplier_id, s.supplier_name
FROM supplier AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM food_product AS fp
    JOIN product_category AS pc USING (category_id)
    WHERE pc.category_name = 'Dairy'
      AND NOT EXISTS (
          SELECT 1
          FROM supplier_product AS sp
          WHERE sp.supplier_id = s.supplier_id
            AND sp.product_id = fp.product_id
      )
);

-- 11. AND and OR: available stock expiring today or already expired.
SELECT batch_id, expiration_date
FROM inventory_batch
WHERE remaining_quantity > 0
  AND (expiration_date < CURRENT_DATE OR expiration_date = CURRENT_DATE)
ORDER BY expiration_date, batch_id;