-- =====================================================================
--  Stock Inventory Management System Database Design
-- =====================================================================
DROP DATABASE IF EXISTS ctrl_alt_elite_db;
CREATE DATABASE ctrl_alt_elite_db;
USE ctrl_alt_elite_db;

-- ---------------------------------------------------------------------
-- 1. TABLES
-- ---------------------------------------------------------------------

CREATE TABLE USER (
    user_id     INT AUTO_INCREMENT PRIMARY KEY,
    username    VARCHAR(50)  NOT NULL UNIQUE,
    password    VARCHAR(255) NOT NULL,          -- stores a salted hash only, never plain text
    role        VARCHAR(20)  NOT NULL DEFAULT 'staff',
    active      BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE CATEGORY (
    category_id   INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE ITEM (
    item_id              INT AUTO_INCREMENT PRIMARY KEY,
    item_code            VARCHAR(20)  NOT NULL UNIQUE,
    description          VARCHAR(255) NOT NULL,
    category_id          INT          NOT NULL,
    quantity             INT          NOT NULL DEFAULT 0,
    minimum_stock_level  INT          NOT NULL DEFAULT 0,
    active               BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_item_category FOREIGN KEY (category_id)
        REFERENCES CATEGORY(category_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_item_quantity CHECK (quantity >= 0),
    CONSTRAINT chk_item_min_level CHECK (minimum_stock_level >= 0)
);

CREATE TABLE STOCK_TRANSACTION (
    transaction_id    INT AUTO_INCREMENT PRIMARY KEY,
    item_id           INT NOT NULL,
    user_id           INT NOT NULL,
    transaction_type  ENUM('IN', 'OUT') NOT NULL,
    quantity          INT NOT NULL,
    transaction_date  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_txn_item FOREIGN KEY (item_id)
        REFERENCES ITEM(item_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_txn_user FOREIGN KEY (user_id)
        REFERENCES USER(user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_txn_quantity CHECK (quantity > 0)
);

-- ---------------------------------------------------------------------
-- 2. INDEXES
-- ---------------------------------------------------------------------

CREATE INDEX idx_item_category ON ITEM(category_id);
CREATE INDEX idx_txn_item ON STOCK_TRANSACTION(item_id);
CREATE INDEX idx_txn_date ON STOCK_TRANSACTION(transaction_date);

-- ---------------------------------------------------------------------
-- 3. TRIGGERS
-- ---------------------------------------------------------------------

DELIMITER //

CREATE TRIGGER trg_txn_after_insert
AFTER INSERT ON STOCK_TRANSACTION
FOR EACH ROW
BEGIN
    IF NEW.transaction_type = 'IN' THEN
        UPDATE ITEM
        SET quantity = quantity + NEW.quantity
        WHERE item_id = NEW.item_id;
    ELSEIF NEW.transaction_type = 'OUT' THEN
        UPDATE ITEM
        SET quantity = quantity - NEW.quantity
        WHERE item_id = NEW.item_id;
    END IF;
END //

DELIMITER ;

-- Note: if an OUT transaction would make stock negative, the CHECK
-- (quantity >= 0) on ITEM makes MySQL reject it. The app should still
-- check stock first, so the user sees a clear message, not a database error.

-- ---------------------------------------------------------------------
-- 4. SEED DATA (for development and testing only)
-- ---------------------------------------------------------------------
-- Passwords shown here are placeholder BCrypt-style hashes for test data only.
INSERT INTO USER (username, password, role, active) VALUES
('sannie_m',  '$2a$10$placeholderhash0000000000000000000000000000000000', 'admin', TRUE),
('palesa_r',  '$2a$10$placeholderhash0000000000000000000000000000000001', 'admin', TRUE),
('ruan_r',    '$2a$10$placeholderhash0000000000000000000000000000000002', 'admin', TRUE),
('kwenza_b',  '$2a$10$placeholderhash0000000000000000000000000000000003', 'staff', TRUE),
('eugene_n',  '$2a$10$placeholderhash0000000000000000000000000000000004', 'admin', TRUE),
('taira_p',   '$2a$10$placeholderhash0000000000000000000000000000000005', 'staff', TRUE);

INSERT INTO CATEGORY (category_name) VALUES
('Stationery'),
('Electronics'),
('Cleaning Supplies');

INSERT INTO ITEM (item_code, description, category_id, quantity, minimum_stock_level, active) VALUES
('STA-001', 'A4 Paper Ream',          1, 100, 20, TRUE),
('STA-002', 'Ballpoint Pen (Box)',    1,  50, 10, TRUE),
('ELE-001', 'HDMI Cable 2m',          2,  30,  5, TRUE),
('ELE-002', 'USB Flash Drive 32GB',   2,  15,  5, TRUE),
('CLN-001', 'Disinfectant Spray',     3,  40, 10, TRUE);

-- Sample transactions (fires the trigger above, so run after ITEM seed)
INSERT INTO STOCK_TRANSACTION (item_id, user_id, transaction_type, quantity) VALUES
(1, 1, 'IN',  50),   -- restock of A4 paper
(3, 2, 'OUT', 10),   -- HDMI cables issued
(4, 3, 'OUT',  5);   -- flash drives issued

-- ---------------------------------------------------------------------
-- 5. VIEWS
-- ---------------------------------------------------------------------

-- Items currently at or below their minimum stock level
CREATE VIEW vw_low_stock_items AS
SELECT
    i.item_id,
    i.item_code,
    i.description,
    c.category_name,
    i.quantity,
    i.minimum_stock_level
FROM ITEM i
JOIN CATEGORY c ON c.category_id = i.category_id
WHERE i.quantity <= i.minimum_stock_level
  AND i.active = TRUE;

-- Full transaction history with item and user names resolved,
-- for the stock/transaction report screen
CREATE VIEW vw_transaction_history AS
SELECT
    t.transaction_id,
    i.item_code,
    i.description,
    t.transaction_type,
    t.quantity,
    u.username,
    t.transaction_date
FROM STOCK_TRANSACTION t
JOIN ITEM i ON i.item_id = t.item_id
JOIN USER u ON u.user_id = t.user_id
ORDER BY t.transaction_date DESC;

-- ---------------------------------------------------------------------
-- End of script
-- ---------------------------------------------------------------------
