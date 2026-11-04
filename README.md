# ”CTRL ALT ELITE” Stock Inventory Management System

## About the Project

The Stock Inventory Management System is a Java desktop application developed to manage inventory items, stock transactions, categories, low-stock alerts, reporting and user accounts.

The system supports two user roles:

**Admin:** Access to all system features, including User Management.

**Staff:** Access to Transactions and Alerts only.

## Requirements

- Java JDK 17
- Apache Maven
- Visual Studio Code or another Java-compatible IDE
- Internet connection for the shared Aiven MySQL database

## How to Run the Application

1. Download the project ZIP from GitHub and extract it.
2. Open the project folder in VS Code.
3. Find `.env.example` in the main project folder.
4. Create a copy named `.env`.
5. Enter the Aiven database password provided by the project administrator.
6. Open a terminal in the folder containing `pom.xml`.
7. Run:

```powershell
mvn compile
mvn exec:java
```

The login screen should open automatically.

## Initial Testing Login

Username: `admin`

Password: Provided by the project administrator.

## User Management

Admin can create users, update account details, reset passwords using Update and deactivate accounts.

When updating an account, leave the Password field blank to keep the existing password.

Passwords are securely stored using BCrypt and cannot be viewed after creation.

## Stock Transactions

Select an inventory item, choose IN or OUT, enter the quantity and click Post.

IN increases stock quantities, while OUT decreases them.

## Database

The application connects to a shared Aiven MySQL database. The `.env` file contains the connection details and is excluded from GitHub.
