CREATE DATABASE expiryalert
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE expiryalert;

CREATE TABLE restaurant (
    restaurant_id INT NOT NULL AUTO_INCREMENT,
    restaurant_name VARCHAR(100) NOT NULL,
    contact_email VARCHAR(100) DEFAULT NULL,
    contact_phone VARCHAR(20) DEFAULT NULL,
    PRIMARY KEY (restaurant_id)
) ENGINE = InnoDB;

CREATE TABLE branch (
    branch_id INT NOT NULL AUTO_INCREMENT,
    restaurant_id INT NOT NULL,
    branch_name VARCHAR(100) NOT NULL,
    address VARCHAR(255) DEFAULT NULL,
    city VARCHAR(100) DEFAULT NULL,
    phone VARCHAR(20) DEFAULT NULL,
    PRIMARY KEY (branch_id),
    CONSTRAINT fk_branch_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurant (restaurant_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE employee (
    employee_id INT NOT NULL AUTO_INCREMENT,
    branch_id INT NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role ENUM('manager', 'staff') NOT NULL,
    email VARCHAR(100) DEFAULT NULL,
    phone VARCHAR(20) DEFAULT NULL,
    PRIMARY KEY (employee_id),
    CONSTRAINT fk_employee_branch FOREIGN KEY (branch_id)
        REFERENCES branch (branch_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE product_category (
    category_id INT NOT NULL AUTO_INCREMENT,
    category_name VARCHAR(100) NOT NULL,
    description TEXT DEFAULT NULL,
    PRIMARY KEY (category_id)
) ENGINE = InnoDB;

CREATE TABLE food_product (
    product_id INT NOT NULL AUTO_INCREMENT,
    category_id INT NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    description TEXT DEFAULT NULL,
    measurement_unit VARCHAR(30) NOT NULL,
    storage_requirements VARCHAR(255) DEFAULT NULL,
    reorder_level DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    expiration_alert_days INT NOT NULL DEFAULT 0,
    PRIMARY KEY (product_id),
    CONSTRAINT fk_food_product_category FOREIGN KEY (category_id)
        REFERENCES product_category (category_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_reorder_level CHECK (reorder_level >= 0),
    CONSTRAINT chk_expiration_days CHECK (expiration_alert_days >= 0)
) ENGINE = InnoDB;

CREATE TABLE supplier (
    supplier_id INT NOT NULL AUTO_INCREMENT,
    supplier_name VARCHAR(100) NOT NULL,
    contact_name VARCHAR(100) DEFAULT NULL,
    phone VARCHAR(20) DEFAULT NULL,
    email VARCHAR(100) DEFAULT NULL,
    address VARCHAR(255) DEFAULT NULL,
    PRIMARY KEY (supplier_id)
) ENGINE = InnoDB;

CREATE TABLE supplier_product (
    supplier_id INT NOT NULL,
    product_id INT NOT NULL,
    PRIMARY KEY (supplier_id, product_id),
    CONSTRAINT fk_supplier_product_supplier FOREIGN KEY (supplier_id)
        REFERENCES supplier (supplier_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_supplier_product_product FOREIGN KEY (product_id)
        REFERENCES food_product (product_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE purchase (
    purchase_id INT NOT NULL AUTO_INCREMENT,
    supplier_id INT NOT NULL,
    branch_id INT NOT NULL,
    purchase_date DATE NOT NULL,
    PRIMARY KEY (purchase_id),
    INDEX ix_purchase_branch_date (branch_id, purchase_date),
    CONSTRAINT fk_purchase_supplier FOREIGN KEY (supplier_id)
        REFERENCES supplier (supplier_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_purchase_branch FOREIGN KEY (branch_id)
        REFERENCES branch (branch_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE purchase_item (
    purchase_item_id INT NOT NULL AUTO_INCREMENT,
    purchase_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity DECIMAL(10,2) NOT NULL,
    unit_cost DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (purchase_item_id),
    CONSTRAINT fk_purchase_item_purchase FOREIGN KEY (purchase_id)
        REFERENCES purchase (purchase_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_purchase_item_product FOREIGN KEY (product_id)
        REFERENCES food_product (product_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_purchase_quantity CHECK (quantity > 0),
    CONSTRAINT chk_unit_cost CHECK (unit_cost >= 0)
) ENGINE = InnoDB;

CREATE TABLE storage_location (
    storage_id INT NOT NULL AUTO_INCREMENT,
    branch_id INT NOT NULL,
    storage_name VARCHAR(100) NOT NULL,
    storage_type VARCHAR(50) NOT NULL,
    PRIMARY KEY (storage_id),
    CONSTRAINT fk_storage_location_branch FOREIGN KEY (branch_id)
        REFERENCES branch (branch_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE inventory_batch (
    batch_id INT NOT NULL AUTO_INCREMENT,
    purchase_item_id INT NOT NULL,
    storage_id INT NOT NULL,
    received_date DATE NOT NULL,
    expiration_date DATE NOT NULL,
    initial_quantity DECIMAL(10,2) NOT NULL,
    remaining_quantity DECIMAL(10,2) NOT NULL,
    batch_status VARCHAR(30) NOT NULL DEFAULT 'available',
    PRIMARY KEY (batch_id),
    INDEX ix_batch_expiration (expiration_date),
    CONSTRAINT fk_inventory_batch_item FOREIGN KEY (purchase_item_id)
        REFERENCES purchase_item (purchase_item_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_inventory_batch_storage FOREIGN KEY (storage_id)
        REFERENCES storage_location (storage_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_initial_quantity CHECK (initial_quantity > 0),
    CONSTRAINT chk_remaining_quantity CHECK (
        remaining_quantity >= 0 AND remaining_quantity <= initial_quantity
    ),
    CONSTRAINT chk_batch_dates CHECK (expiration_date >= received_date)
) ENGINE = InnoDB;

CREATE TABLE expiration_alert (
    alert_id INT NOT NULL AUTO_INCREMENT,
    batch_id INT NOT NULL,
    alert_date DATE NOT NULL,
    alert_type VARCHAR(50) NOT NULL,
    notification_status VARCHAR(30) NOT NULL DEFAULT 'pending',
    pending_alert_type VARCHAR(50) GENERATED ALWAYS AS (
        CASE WHEN notification_status = 'pending' THEN alert_type ELSE NULL END
    ) STORED,
    PRIMARY KEY (alert_id),
    UNIQUE KEY uq_pending_alert (batch_id, pending_alert_type),
    UNIQUE KEY uq_alert_per_day (batch_id, alert_type, alert_date),
    CONSTRAINT fk_expiration_alert_batch FOREIGN KEY (batch_id)
        REFERENCES inventory_batch (batch_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_notification_status CHECK (
        notification_status IN ('pending', 'acknowledged')
    ),
    CONSTRAINT chk_alert_type CHECK (
        alert_type IN ('Expired', 'Approaching Expiration')
    )
) ENGINE = InnoDB;

CREATE TABLE inventory_movement (
    movement_id INT NOT NULL AUTO_INCREMENT,
    batch_id INT NOT NULL,
    employee_id INT NOT NULL,
    movement_type VARCHAR(50) NOT NULL,
    quantity DECIMAL(10,2) NOT NULL,
    movement_date DATETIME NOT NULL,
    notes TEXT DEFAULT NULL,
    PRIMARY KEY (movement_id),
    CONSTRAINT fk_inventory_movement_batch FOREIGN KEY (batch_id)
        REFERENCES inventory_batch (batch_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_inventory_movement_employee FOREIGN KEY (employee_id)
        REFERENCES employee (employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_movement_quantity CHECK (quantity > 0),
    CONSTRAINT chk_movement_type CHECK (
        movement_type IN ('usage', 'adjust_in', 'adjust_out')
    )
) ENGINE = InnoDB;

CREATE TABLE food_waste (
    waste_id INT NOT NULL AUTO_INCREMENT,
    batch_id INT NOT NULL,
    employee_id INT NOT NULL,
    discarded_quantity DECIMAL(10,2) NOT NULL,
    disposal_reason VARCHAR(255) NOT NULL,
    disposal_date DATE NOT NULL,
    estimated_loss DECIMAL(20,4) NOT NULL,
    PRIMARY KEY (waste_id),
    INDEX ix_waste_disposal_date (disposal_date),
    CONSTRAINT fk_food_waste_batch FOREIGN KEY (batch_id)
        REFERENCES inventory_batch (batch_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_food_waste_employee FOREIGN KEY (employee_id)
        REFERENCES employee (employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT chk_discarded_quantity CHECK (discarded_quantity > 0),
    CONSTRAINT chk_estimated_loss CHECK (estimated_loss >= 0),
    CONSTRAINT chk_disposal_reason CHECK (CHAR_LENGTH(TRIM(disposal_reason)) > 0)
) ENGINE = InnoDB;