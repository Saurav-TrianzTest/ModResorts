package com.acme.modres;

import java.io.IOException;
import java.io.PrintWriter;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

// Replaced WebSphere-specific com.ibm.websphere.servlet.response.ResponseUtils import (blocker-2, blocker-7)
// with standard Java HTML encoding for container-native deployment on AWS ECS/EKS

@WebServlet("/resorts/upper")
public class UpperServlet extends HttpServlet {

  private static final long serialVersionUID = 1L;

  /**
   * Encodes a string for safe HTML output by escaping special characters.
   * Replaces WebSphere ResponseUtils.encodeDataString() (blocker-2, blocker-7).
   */
  private static String encodeDataString(String input) {
    if (input == null) {
      return "";
    }
    return input.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#x27;");
  }

  @Override
  protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
    response.setContentType("text/html");

    String originalStr = request.getParameter("input");
    if (originalStr == null) {
      originalStr = "";
    }

    String newStr = originalStr.toUpperCase();
    // Replaced ResponseUtils.encodeDataString() with standard HTML encoding (blocker-2, blocker-7)
    newStr = encodeDataString(newStr);

    PrintWriter out = response.getWriter();
    out.print("<br/><b>upper case input " + newStr + "</b>");
  }
}
