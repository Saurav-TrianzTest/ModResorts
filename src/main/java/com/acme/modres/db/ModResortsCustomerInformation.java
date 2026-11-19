package com.acme.modres.db;

import javax.annotation.Resource;
import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;

public class ModResortsCustomerInformation {
  private static final String SELECT_CUSTOMERS_QUERY = "SELECT INFO FROM CUSTOMER";

  // Externalize singleton state: read customer information from an
  // environment variable so all EKS pod replicas share the same data
  // instead of holding state in JVM heap memory
  // Removing DB connection for ease of demo setup
  // @Resource(lookup = "jdbc/ModResortsJndi")
  private DataSource dataSource;

  public ArrayList<String> getCustomerInformation() {
    Connection conn = null;
    PreparedStatement stmt = null;
    ResultSet rs = null;
    ArrayList<String> customerInfo = new ArrayList<>();

    try {
      // Externalize singleton state: read customer information from an
      // environment variable so all EKS pod replicas share the same data
      String envCustomerInfo = System.getenv("CUSTOMER_INFO");
      if (envCustomerInfo != null && envCustomerInfo.trim().length() > 0) {
        for (String info : envCustomerInfo.split(",")) {
          customerInfo.add(info.trim());
        }
      }
      if (customerInfo.isEmpty() && dataSource != null) {
        // Get a connection from the injected data source
        conn = dataSource.getConnection();
        // Create a prepared statement
        stmt = conn.prepareStatement(SELECT_CUSTOMERS_QUERY);
        // Execute the query
        rs = stmt.executeQuery();

        // Process the results
        while (rs.next()) {
          String info = rs.getString("INFO");
          customerInfo.add(info);
        }
      }

    } catch (SQLException e) {
      e.printStackTrace();
    } finally {
      // Close the result set, statement, and connection
      try {
        if (rs != null)
          rs.close();
        if (stmt != null)
          stmt.close();
        if (conn != null)
          conn.close();
      } catch (SQLException e) {
        e.printStackTrace();
      }
    }
    return customerInfo;
  }
}
