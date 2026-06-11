package com.acme.modres.exception;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

import jakarta.servlet.ServletException;
import java.util.logging.Logger;

public class ExceptionHandlerTest {

    private static final Logger logger = Logger.getLogger(ExceptionHandlerTest.class.getName());

    @Test
    void handleException_withNullException_throwsServletException() {
        // Arrange
        String errorMsg = "Test error message";

        // Act & Assert
        assertThrows(ServletException.class, () -> {
            ExceptionHandler.handleException(null, errorMsg, logger);
        });
    }

    @Test
    void handleException_withNonNullException_throwsServletExceptionWithCause() {
        // Arrange
        Exception cause = new RuntimeException("Root cause");
        String errorMsg = "Test error message";

        // Act & Assert
        ServletException thrown = assertThrows(ServletException.class, () -> {
            ExceptionHandler.handleException(cause, errorMsg, logger);
        });
        assertNotNull(thrown.getCause());
        assertEquals(cause, thrown.getCause());
    }

    @Test
    void handleException_withNullException_servletExceptionHasCorrectMessage() {
        // Arrange
        String errorMsg = "Specific error message";

        // Act & Assert
        ServletException thrown = assertThrows(ServletException.class, () -> {
            ExceptionHandler.handleException(null, errorMsg, logger);
        });
        assertEquals(errorMsg, thrown.getMessage());
    }

    @Test
    void handleException_withNonNullException_servletExceptionHasCorrectMessage() {
        // Arrange
        Exception cause = new IllegalArgumentException("Bad argument");
        String errorMsg = "Wrapped error message";

        // Act & Assert
        ServletException thrown = assertThrows(ServletException.class, () -> {
            ExceptionHandler.handleException(cause, errorMsg, logger);
        });
        assertEquals(errorMsg, thrown.getMessage());
    }

    @Test
    void handleException_withIOException_wrapsCorrectly() {
        // Arrange
        Exception cause = new java.io.IOException("IO error");
        String errorMsg = "IO error occurred";

        // Act & Assert
        ServletException thrown = assertThrows(ServletException.class, () -> {
            ExceptionHandler.handleException(cause, errorMsg, logger);
        });
        assertNotNull(thrown);
        assertEquals(cause, thrown.getCause());
    }

    @Test
    void handleException_withEmptyMessage_throwsServletException() {
        // Arrange
        String errorMsg = "";

        // Act & Assert
        assertThrows(ServletException.class, () -> {
            ExceptionHandler.handleException(null, errorMsg, logger);
        });
    }
}
