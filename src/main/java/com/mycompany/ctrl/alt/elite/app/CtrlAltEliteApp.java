package com.mycompany.ctrl.alt.elite.app;

/** Start the inventory system with the login window. */
public class CtrlAltEliteApp {
    public static void main(String[] args) {
        java.awt.EventQueue.invokeLater(() -> new LoginFrame().setVisible(true));
    }
}
