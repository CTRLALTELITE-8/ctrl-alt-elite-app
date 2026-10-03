/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 */

package com.mycompany.ctrl.alt.elite.app;

import io.github.cdimascio.dotenv.Dotenv;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

/**
 *
 * @author ruanr
 */
public class CtrlAltEliteApp {

    public static void main(String[] args) {
        
        // Test Database Connection and print version
        Dotenv dotenv = Dotenv.load();

        String url = String.format("jdbc:mysql://%s:%s/%s?sslMode=REQUIRED",
                dotenv.get("DB_HOST"),
                dotenv.get("DB_PORT"),
                dotenv.get("DB_NAME"));

        System.out.println("Connecting to database...");

        try (Connection conn = DriverManager.getConnection(url, dotenv.get("DB_USER"), dotenv.get("DB_PASSWORD"));
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT * FROM db_version")) {

            System.out.println("Connected successfully!\n");

            while (rs.next()) {
                System.out.println("Version: " + rs.getString(2));
            }

        } catch (Exception e) {
            System.err.println("Database Connection Failed: " + e.getMessage());
        }
    }
}
