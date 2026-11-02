package com.mycompany.ctrl.alt.elite.app;

import io.github.cdimascio.dotenv.Dotenv;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import org.mindrot.jbcrypt.BCrypt;

public class BackendService {

    public record User(int id, String username, String role) {}

    public record Choice(int id, String name) {
        @Override public String toString() { return name; }
    }

    // .env is local only and must never be committed to GitHub.
    private final Dotenv env = Dotenv.configure().ignoreIfMissing().load();

    private String setting(String key, String fallback) {
        String value = System.getenv(key);
        if (value == null || value.isBlank()) value = env.get(key);
        return (value == null || value.isBlank()) ? fallback : value;
    }

    private Connection connect() throws SQLException {
        String host = setting("DB_HOST", "localhost");
        String port = setting("DB_PORT", "3306");
        String db = setting("DB_NAME", "ctrl_alt_elite_db");
        String user = setting("DB_USER", "root");
        String password = setting("DB_PASSWORD", "");
        String ssl = setting("DB_SSL_MODE", "REQUIRED");
        String url = "jdbc:mysql://" + host + ":" + port + "/" + db + "?sslMode=" + ssl;
        return DriverManager.getConnection(url, user, password);
    }

    /** Returns null if the credentials do not match or account is inactive. */
    public User login(String username, char[] password) throws SQLException {
        String sql = "SELECT user_id, username, password, role FROM USER "
                + "WHERE username = ? AND active = TRUE";
        try (Connection con = connect(); PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, username.trim());
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return null;
                String hash = rs.getString("password");
                boolean matches;
                try {
                    matches = BCrypt.checkpw(new String(password), hash);
                } catch (IllegalArgumentException ex) {
                    matches = false;
                }
                if (!matches) return null;
                return new User(rs.getInt("user_id"), rs.getString("username"), rs.getString("role"));
            }
        }
    }

    // Categories
    public List<Choice> categories() throws SQLException {
        List<Choice> result = new ArrayList<>();
        try (Connection con = connect();
             PreparedStatement ps = con.prepareStatement(
                     "SELECT category_id, category_name FROM CATEGORY ORDER BY category_name");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) result.add(new Choice(rs.getInt(1), rs.getString(2)));
        }
        return result;
    }

    public void addCategory(String name) throws SQLException {
        requireText(name, "Category name");
        runUpdate("INSERT INTO CATEGORY (category_name) VALUES (?)", name.trim());
    }

    public void updateCategory(int id, String name) throws SQLException {
        requireId(id); requireText(name, "Category name");
        runUpdate("UPDATE CATEGORY SET category_name=? WHERE category_id=?", name.trim(), id);
    }

    public void deleteCategory(int id) throws SQLException {
        requireId(id);
        runUpdate("DELETE FROM CATEGORY WHERE category_id=?", id);
    }

    //Inventory
    public List<Object[]> inventory() throws SQLException {
        return rows("SELECT i.item_id, i.item_code, i.description, c.category_name, "
                + "i.quantity, i.minimum_stock_level, i.active "
                + "FROM ITEM i JOIN CATEGORY c ON i.category_id=c.category_id ORDER BY i.item_id", 7);
    }

    public List<Choice> activeItems() throws SQLException {
        List<Choice> result = new ArrayList<>();
        try (Connection con = connect();
             PreparedStatement ps = con.prepareStatement(
                     "SELECT item_id, item_code, description FROM ITEM WHERE active=TRUE ORDER BY item_code");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                result.add(new Choice(rs.getInt(1), rs.getString(2) + " - " + rs.getString(3)));
            }
        }
        return result;
    }

    public void addItem(String code, String description, int categoryId, int minStock) throws SQLException {
        requireText(code, "Item code"); requireText(description, "Description");
        requireId(categoryId);
        if (minStock < 0) throw new IllegalArgumentException("Minimum stock cannot be negative.");
        
        runUpdate("INSERT INTO ITEM (item_code, description, category_id, quantity, minimum_stock_level) "
                + "VALUES (?, ?, ?, 0, ?)", code.trim(), description.trim(), categoryId, minStock);
    }

    public void updateItem(int id, String code, String description, int categoryId, int minStock)
            throws SQLException {
        requireId(id); requireText(code, "Item code"); requireText(description, "Description");
        requireId(categoryId);
        if (minStock < 0) throw new IllegalArgumentException("Minimum stock cannot be negative.");
        runUpdate("UPDATE ITEM SET item_code=?, description=?, category_id=?, minimum_stock_level=? "
                + "WHERE item_id=? AND active=TRUE", code.trim(), description.trim(), categoryId, minStock, id);
    }

    public void deactivateItem(int id) throws SQLException {
        requireId(id);
        runUpdate("UPDATE ITEM SET active=FALSE WHERE item_id=?", id);
    }

    //Stock IN / OUT
    public void recordStock(int itemId, int userId, String type, int quantity) throws SQLException {
        requireId(itemId); requireId(userId);
        if (quantity <= 0) throw new IllegalArgumentException("Quantity must be greater than zero.");
        if (!"IN".equals(type) && !"OUT".equals(type))
            throw new IllegalArgumentException("Choose IN or OUT.");

        try (Connection con = connect()) {
            con.setAutoCommit(false);
            try {
                
                try (PreparedStatement ps = con.prepareStatement(
                        "SELECT quantity FROM ITEM WHERE item_id=? AND active=TRUE FOR UPDATE")) {
                    ps.setInt(1, itemId);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new IllegalArgumentException("Item is not active or does not exist.");
                        if ("OUT".equals(type) && rs.getInt(1) < quantity)
                            throw new IllegalArgumentException("Not enough stock available.");
                    }
                }
                try (PreparedStatement ps = con.prepareStatement(
                        "INSERT INTO STOCK_TRANSACTION (item_id, user_id, transaction_type, quantity) "
                        + "VALUES (?, ?, ?, ?)")) {
                    ps.setInt(1, itemId);
                    ps.setInt(2, userId);
                    ps.setString(3, type);
                    ps.setInt(4, quantity);
                    ps.executeUpdate();
                }
                
                
                con.commit();
            } catch (SQLException | RuntimeException ex) {
                con.rollback();
                throw ex;
            }
        }
    }

    public List<Object[]> transactions() throws SQLException {
        return rows("SELECT transaction_id, item_code, transaction_type, quantity, username, "
                + "transaction_date FROM vw_transaction_history ORDER BY transaction_date DESC, transaction_id DESC", 6);
    }

    public List<Object[]> lowStock() throws SQLException {
        return rows("SELECT item_id, item_code, description, category_name, quantity, minimum_stock_level "
                + "FROM vw_low_stock_items ORDER BY quantity, item_code", 6);
    }

    //Small reusable JDBC helpers
    private List<Object[]> rows(String sql, int count) throws SQLException {
        List<Object[]> result = new ArrayList<>();
        try (Connection con = connect(); PreparedStatement ps = con.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Object[] row = new Object[count];
                for (int i = 0; i < count; i++) row[i] = rs.getObject(i + 1);
                result.add(row);
            }
        }
        return result;
    }

    private void runUpdate(String sql, Object... values) throws SQLException {
        try (Connection con = connect(); PreparedStatement ps = con.prepareStatement(sql)) {
            for (int i = 0; i < values.length; i++) ps.setObject(i + 1, values[i]);
            ps.executeUpdate();
        }
    }

    private static void requireId(int id) {
        if (id <= 0) throw new IllegalArgumentException("Select a valid record first.");
    }

    private static void requireText(String text, String label) {
        if (text == null || text.isBlank()) throw new IllegalArgumentException(label + " is required.");
    }
}
