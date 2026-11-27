USE expiryalert;

CREATE OR REPLACE VIEW v_batch_details AS
SELECT ib.*,
       fp.product_id,
       fp.product_name,
       fp.measurement_unit,
       p.branch_id,
       b.branch_name,
       sl.storage_name,
       DATEDIFF(ib.expiration_date, CURRENT_DATE) AS days_until_expiration,
       CASE
           WHEN ib.remaining_quantity = 0 THEN 'Depleted'
           WHEN ib.expiration_date < CURRENT_DATE THEN 'Expired'
           WHEN DATEDIFF(ib.expiration_date, CURRENT_DATE) <= fp.expiration_alert_days
               THEN 'Approaching Expiration'
           ELSE 'Safe'
       END AS expiration_status
FROM inventory_batch AS ib
JOIN purchase_item AS pi USING (purchase_item_id)
JOIN food_product AS fp USING (product_id)
JOIN purchase AS p USING (purchase_id)
JOIN branch AS b ON b.branch_id = p.branch_id
JOIN storage_location AS sl ON sl.storage_id = ib.storage_id;

CREATE OR REPLACE VIEW v_branch_stock AS
SELECT b.branch_id,
       b.branch_name,
       fp.product_id,
       fp.product_name,
       fp.measurement_unit,
       fp.reorder_level,
       COALESCE(SUM(v.remaining_quantity), 0) AS stock_quantity,
       COALESCE(SUM(
           CASE WHEN v.expiration_date >= CURRENT_DATE THEN v.remaining_quantity ELSE 0 END
       ), 0) AS usable_quantity
FROM branch AS b
CROSS JOIN food_product AS fp
LEFT JOIN v_batch_details AS v
    ON v.branch_id = b.branch_id AND v.product_id = fp.product_id
GROUP BY b.branch_id, b.branch_name, fp.product_id, fp.product_name,
         fp.measurement_unit, fp.reorder_level;

CREATE OR REPLACE VIEW v_purchase_totals AS
SELECT p.purchase_id,
       p.branch_id,
       b.branch_name,
       s.supplier_name,
       p.purchase_date,
       COUNT(pi.purchase_item_id) AS item_count,
       SUM(pi.quantity * pi.unit_cost) AS total_cost
FROM purchase AS p
JOIN purchase_item AS pi USING (purchase_id)
JOIN supplier AS s USING (supplier_id)
JOIN branch AS b USING (branch_id)
GROUP BY p.purchase_id, p.branch_id, b.branch_name, s.supplier_name, p.purchase_date;

CREATE OR REPLACE VIEW v_waste_report AS
SELECT v.branch_id,
       v.branch_name,
       v.product_id,
       v.product_name,
       v.measurement_unit,
       fw.disposal_reason,
       COUNT(*) AS records,
       SUM(fw.discarded_quantity) AS discarded,
       SUM(fw.estimated_loss) AS total_loss
FROM food_waste AS fw
JOIN v_batch_details AS v USING (batch_id)
GROUP BY v.branch_id, v.branch_name, v.product_id, v.product_name,
         v.measurement_unit, fw.disposal_reason;