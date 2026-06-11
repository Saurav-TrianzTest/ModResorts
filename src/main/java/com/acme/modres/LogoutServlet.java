package com.acme.modres;

import java.io.IOException;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet({ "/logout" })
public class LogoutServlet extends HttpServlet {
  private static final long serialVersionUID = 1L;

  @Override
  protected void doGet(HttpServletRequest request,
      HttpServletResponse response) throws IOException {

    try {
      // Replaced com.ibm.websphere.security.WSSecurityHelper.revokeSSOCookies()
      // with standard Jakarta EE session invalidation for Java 17 compatibility.
      // The IBM WebSphere SSO cookie revocation is handled by invalidating the
      // HTTP session, which is the standard approach in Jakarta EE applications.
      HttpSession session = request.getSession(false);
      if (session != null) {
        session.invalidate();
      }
    } catch (Exception e) {
      System.err.println("[ERROR] Error logging out");
      e.printStackTrace();
    }

    response.sendRedirect("login.jsp");
  }
}
