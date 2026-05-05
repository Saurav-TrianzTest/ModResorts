package com.acme.modres;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;

/**
 * Health check endpoint for container orchestration platforms (ECS/EKS).
 * Provides basic application health status for liveness and readiness probes.
 * 
 * Endpoints:
 * - GET /health - Basic health check
 * - GET /health/live - Liveness probe (is the application running?)
 * - GET /health/ready - Readiness probe (is the application ready to serve traffic?)
 */
@WebServlet(urlPatterns = {"/health", "/health/live", "/health/ready"})
public class HealthCheckServlet extends HttpServlet {
  private static final long serialVersionUID = 1L;

  @Override
  protected void doGet(HttpServletRequest request, HttpServletResponse response) 
      throws ServletException, IOException {
    
    String path = request.getServletPath();
    
    response.setContentType("application/json");
    response.setCharacterEncoding("UTF-8");
    
    try {
      if ("/health/live".equals(path)) {
        handleLivenessProbe(response);
      } else if ("/health/ready".equals(path)) {
        handleReadinessProbe(response);
      } else {
        handleBasicHealth(response);
      }
    } catch (Exception e) {
      response.setStatus(HttpServletResponse.SC_SERVICE_UNAVAILABLE);
      PrintWriter out = response.getWriter();
      out.print("{\"status\":\"DOWN\",\"error\":\"" + e.getMessage() + "\"}");
    }
  }

  /**
   * Liveness probe - checks if the application is running
   */
  private void handleLivenessProbe(HttpServletResponse response) throws IOException {
    response.setStatus(HttpServletResponse.SC_OK);
    PrintWriter out = response.getWriter();
    out.print("{\"status\":\"UP\",\"check\":\"liveness\"}");
  }

  /**
   * Readiness probe - checks if the application is ready to serve traffic
   */
  private void handleReadinessProbe(HttpServletResponse response) throws IOException {
    // Check if application is ready (e.g., dependencies initialized)
    boolean isReady = checkReadiness();
    
    if (isReady) {
      response.setStatus(HttpServletResponse.SC_OK);
      PrintWriter out = response.getWriter();
      out.print("{\"status\":\"UP\",\"check\":\"readiness\"}");
    } else {
      response.setStatus(HttpServletResponse.SC_SERVICE_UNAVAILABLE);
      PrintWriter out = response.getWriter();
      out.print("{\"status\":\"DOWN\",\"check\":\"readiness\"}");
    }
  }

  /**
   * Basic health check with system information
   */
  private void handleBasicHealth(HttpServletResponse response) throws IOException {
    MemoryMXBean memoryBean = ManagementFactory.getMemoryMXBean();
    long usedMemory = memoryBean.getHeapMemoryUsage().getUsed();
    long maxMemory = memoryBean.getHeapMemoryUsage().getMax();
    
    response.setStatus(HttpServletResponse.SC_OK);
    PrintWriter out = response.getWriter();
    
    StringBuilder json = new StringBuilder();
    json.append("{");
    json.append("\"status\":\"UP\",");
    json.append("\"application\":\"ModResorts\",");
    json.append("\"version\":\"2.0.0\",");
    json.append("\"memory\":{");
    json.append("\"used\":").append(usedMemory).append(",");
    json.append("\"max\":").append(maxMemory);
    json.append("},");
    json.append("\"timestamp\":\"").append(System.currentTimeMillis()).append("\"");
    json.append("}");
    
    out.print(json.toString());
  }

  /**
   * Check if application is ready to serve traffic
   * Can be extended to check database connections, external services, etc.
   */
  private boolean checkReadiness() {
    // Basic readiness check - application is running
    // Extend this to check:
    // - Database connectivity
    // - External service availability
    // - Required resources initialization
    return true;
  }
}
