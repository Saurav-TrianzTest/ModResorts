package com.acme.modres;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class LogoutServletTest {

    private LogoutServlet logoutServlet;

    @Mock
    private HttpServletRequest mockRequest;

    @Mock
    private HttpServletResponse mockResponse;

    @Mock
    private HttpSession mockSession;

    @BeforeEach
    void setUp() {
        logoutServlet = new LogoutServlet();
    }

    @Test
    void doGet_withActiveSession_invalidatesSession() throws Exception {
        // Arrange
        when(mockRequest.getSession(false)).thenReturn(mockSession);

        // Act
        logoutServlet.doGet(mockRequest, mockResponse);

        // Assert
        verify(mockSession).invalidate();
        verify(mockResponse).sendRedirect("login.jsp");
    }

    @Test
    void doGet_withNoSession_redirectsToLogin() throws Exception {
        // Arrange
        when(mockRequest.getSession(false)).thenReturn(null);

        // Act
        logoutServlet.doGet(mockRequest, mockResponse);

        // Assert
        verify(mockSession, never()).invalidate();
        verify(mockResponse).sendRedirect("login.jsp");
    }

    @Test
    void doGet_alwaysRedirectsToLoginJsp() throws Exception {
        // Arrange
        when(mockRequest.getSession(false)).thenReturn(null);

        // Act
        logoutServlet.doGet(mockRequest, mockResponse);

        // Assert
        verify(mockResponse).sendRedirect("login.jsp");
    }

    @Test
    void doGet_withSessionInvalidateException_stillRedirects() throws Exception {
        // Arrange
        when(mockRequest.getSession(false)).thenReturn(mockSession);
        doThrow(new RuntimeException("Session error")).when(mockSession).invalidate();

        // Act - should not throw
        assertDoesNotThrow(() -> logoutServlet.doGet(mockRequest, mockResponse));

        // Assert
        verify(mockResponse).sendRedirect("login.jsp");
    }
}
