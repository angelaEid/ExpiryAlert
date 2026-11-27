USE expiryalert;

START TRANSACTION;

INSERT INTO restaurant
    (restaurant_id, restaurant_name, contact_email, contact_phone)
VALUES
    (1, 'ExpiryAlert Demo Restaurant', 'restaurant@example.com', '70123456');

INSERT INTO branch
    (branch_id, restaurant_id, branch_name, address, city, phone)
VALUES
    (1, 1, 'Hamra Branch', 'Hamra Street', 'Beirut', '70111222'),
    (2, 1, 'Achrafieh Branch', 'Sassine Square', 'Beirut', '01999111'),
    (3, 1, 'Verdun Branch', 'Verdun Street', 'Beirut', NULL);

INSERT INTO employee
    (employee_id, branch_id, full_name, role, email, phone)
VALUES
    (1, 1, 'Demo Manager', 'manager', 'manager@example.com', '70333444'),
    (2, 2, 'Demo Staff', 'staff', 'staff@example.com', '01999112'),
    (3, 3, 'Verdun Demo Staff', 'staff', NULL, NULL);

INSERT INTO product_category
    (category_id, category_name, description)
VALUES
    (1, 'Dairy', 'Milk, cheese, and dairy products'),
    (2, 'Vegetables', 'Fresh vegetables'),
    (3, 'Meat', 'Fresh meat products');

INSERT INTO food_product
    (product_id, category_id, product_name, description, measurement_unit,
     storage_requirements, reorder_level, expiration_alert_days)
VALUES
    (1, 1, 'Milk', 'Fresh milk', 'Liter', 'Refrigerated', 20.00, 3),
    (2, 2, 'Tomatoes', 'Fresh tomatoes', 'Kg', 'Cool storage', 15.00, 2),
    (3, 3, 'Chicken', 'Fresh chicken', 'Kg', 'Refrigerated', 10.00, 2);

INSERT INTO supplier
    (supplier_id, supplier_name, contact_name, phone, email, address)
VALUES
    (1, 'Fresh Foods Supplier', 'Demo Contact', '70999888', 'supplier@example.com', 'Beirut'),
    (2, 'Garden Market', 'Demo Contact', '01999113', 'market@example.com', 'Beirut'),
    (3, 'Cedars Dairy Supply', NULL, NULL, NULL, 'Beirut'),
    (4, 'Coastal Poultry Supply', NULL, NULL, NULL, 'Beirut');

INSERT INTO supplier_product (supplier_id, product_id)
VALUES (1, 1), (1, 2), (1, 3), (2, 2), (3, 1), (4, 3);

INSERT INTO purchase (purchase_id, supplier_id, branch_id, purchase_date)
VALUES
    (1, 1, 1, CURRENT_DATE - INTERVAL 3 DAY),
    (2, 2, 2, CURRENT_DATE - INTERVAL 1 DAY);

INSERT INTO purchase_item (purchase_item_id, purchase_id, product_id, quantity, unit_cost)
VALUES
    (1, 1, 1, 50.00, 2.50),
    (2, 1, 2, 30.00, 1.50),
    (3, 1, 3, 20.00, 5.00),
    (4, 2, 2, 6.00, 1.75);

INSERT INTO storage_location (storage_id, branch_id, storage_name, storage_type)
VALUES
    (1, 1, 'Main Refrigerator', 'Refrigerator'),
    (2, 1, 'Dry Storage', 'Dry Storage'),
    (3, 2, 'Walk-in Refrigerator', 'Refrigerator'),
    (4, 2, 'Dry Storage', 'Dry Storage'),
    (5, 3, 'Main Refrigerator', 'Refrigerator'),
    (6, 3, 'Dry Storage', 'Dry Storage');

-- Purchase item 3 is split into two 10 kg batches.
INSERT INTO inventory_batch
    (batch_id, purchase_item_id, storage_id, received_date, expiration_date,
     initial_quantity, remaining_quantity)
VALUES
    (1, 1, 1, CURRENT_DATE - INTERVAL 3 DAY, CURRENT_DATE, 50.00, 35.00),
    (2, 2, 2, CURRENT_DATE - INTERVAL 3 DAY, CURRENT_DATE + INTERVAL 3 DAY, 30.00, 30.00),
    (3, 3, 1, CURRENT_DATE - INTERVAL 3 DAY, CURRENT_DATE - INTERVAL 1 DAY, 10.00, 5.00),
    (4, 3, 1, CURRENT_DATE - INTERVAL 2 DAY, CURRENT_DATE - INTERVAL 2 DAY, 10.00, 10.00),
    (5, 4, 3, CURRENT_DATE - INTERVAL 1 DAY, CURRENT_DATE + INTERVAL 1 DAY, 6.00, 6.00);

INSERT INTO inventory_movement
    (movement_id, batch_id, employee_id, movement_type, quantity, movement_date, notes)
VALUES
    (1, 1, 1, 'usage', 10.00,
     TIMESTAMP(CURRENT_DATE - INTERVAL 3 DAY, '12:00:00'), 'Used for food preparation'),
    (2, 1, 1, 'usage', 5.00,
     TIMESTAMP(CURRENT_DATE - INTERVAL 2 DAY, '15:30:00'), 'Used during service');

INSERT INTO food_waste
    (waste_id, batch_id, employee_id, discarded_quantity, disposal_reason,
     disposal_date, estimated_loss)
VALUES
    (1, 3, 1, 5.00, 'Spoiled chicken', CURRENT_DATE - INTERVAL 1 DAY, 25.0000);

COMMIT;
