package com.acme.modres;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.PrintWriter;
import java.io.StringWriter;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class WelcomeServletTest {

    private WelcomeServlet welcomeServlet;

    @Mock
    private HttpServletRequest mockRequest;

    @Mock
    private HttpServletResponse mockResponse;

    @BeforeEach
    void setUp() {
        welcomeServlet = new WelcomeServlet();
    }

    @Test
    void doGet_setsContentTypePlain() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        welcomeServlet.doGet(mockRequest, mockResponse);

        // Assert
        verify(mockResponse).setContentType("text/plain");
    }

    @Test
    void doGet_writesEnjoyMessage() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        welcomeServlet.doGet(mockRequest, mockResponse);

        // Assert
        String output = stringWriter.toString();
        assertTrue(output.contains("Enjoy!"));
    }

    @Test
    void doGet_doesNotThrowException() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act & Assert
        assertDoesNotThrow(() -> welcomeServlet.doGet(mockRequest, mockResponse));
    }

    @Test
    void doGet_writesNonNullOutput() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        welcomeServlet.doGet(mockRequest, mockResponse);

        // Assert
        assertNotNull(stringWriter.toString());
        assertFalse(stringWriter.toString().isEmpty());
    }
}
