-- ---------------------------------------------------------------------
-- 1. ALERTS TAB: active items at or below their minimum stock level,
--    most urgent first.
-- ---------------------------------------------------------------------
USE ctrl_alt_elite_db;
CREATE OR REPLACE VIEW vw_low_stock_alerts AS
SELECT
    i.item_id,
    i.item_code,
    i.description,
    c.category_name,
    i.quantity,
    i.minimum_stock_level,
    (i.minimum_stock_level - i.quantity) AS units_below_minimum,
    CASE WHEN i.quantity = 0 THEN 'OUT OF STOCK' ELSE 'LOW STOCK' END AS alert_status
FROM ITEM i
JOIN CATEGORY c ON c.category_id = i.category_id
WHERE i.active = TRUE
  AND i.quantity <= i.minimum_stock_level
ORDER BY i.quantity ASC, units_below_minimum DESC;

-- ---------------------------------------------------------------------
-- 2. REPORT: stock summary per category (items, units, items needing
--    restock).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_stock_by_category AS
SELECT
    c.category_id,
    c.category_name,
    COUNT(i.item_id) AS total_items,
    COALESCE(SUM(i.quantity), 0) AS total_units_in_stock,
    COALESCE(SUM(i.quantity <= i.minimum_stock_level), 0) AS items_low_on_stock
FROM CATEGORY c
LEFT JOIN ITEM i ON i.category_id = c.category_id AND i.active = TRUE
GROUP BY c.category_id, c.category_name
ORDER BY c.category_name;

-- ---------------------------------------------------------------------
-- 3. REPORT: stock movement per item (total received, issued, net
--    change and the date of the last transaction).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_stock_movement_summary AS
SELECT
    i.item_id,
    i.item_code,
    i.description,
    c.category_name,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'IN'  THEN t.quantity END), 0) AS total_in,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'OUT' THEN t.quantity END), 0) AS total_out,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'IN'  THEN t.quantity END), 0)
      - COALESCE(SUM(CASE WHEN t.transaction_type = 'OUT' THEN t.quantity END), 0) AS net_change,
    i.quantity AS current_quantity,
    MAX(t.transaction_date) AS last_transaction_date
FROM ITEM i
JOIN CATEGORY c ON c.category_id = i.category_id
LEFT JOIN STOCK_TRANSACTION t ON t.item_id = i.item_id
GROUP BY i.item_id, i.item_code, i.description, c.category_name, i.quantity
ORDER BY i.item_code;

-- ---------------------------------------------------------------------
-- 4. REPORT: activity per user (how many transactions each user
--    recorded and the units they received/issued).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_user_activity AS
SELECT
    u.user_id,
    u.username,
    u.role,
    COUNT(t.transaction_id) AS total_transactions,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'IN'  THEN t.quantity END), 0) AS units_received,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'OUT' THEN t.quantity END), 0) AS units_issued,
    MAX(t.transaction_date) AS last_activity
FROM USER u
LEFT JOIN STOCK_TRANSACTION t ON t.user_id = u.user_id
GROUP BY u.user_id, u.username, u.role
ORDER BY total_transactions DESC, u.username;
