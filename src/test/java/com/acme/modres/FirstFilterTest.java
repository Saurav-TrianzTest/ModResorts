package com.acme.modres;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import jakarta.servlet.FilterChain;
import jakarta.servlet.FilterConfig;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.PrintWriter;
import java.io.StringWriter;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class FirstFilterTest {

    private FirstFilter firstFilter;

    @Mock
    private HttpServletRequest mockRequest;

    @Mock
    private HttpServletResponse mockResponse;

    @Mock
    private FilterChain mockFilterChain;

    @Mock
    private FilterConfig mockFilterConfig;

    @BeforeEach
    void setUp() {
        firstFilter = new FirstFilter();
    }

    @Test
    void init_doesNotThrowException() throws Exception {
        assertDoesNotThrow(() -> firstFilter.init(mockFilterConfig));
    }

    @Test
    void destroy_doesNotThrowException() {
        assertDoesNotThrow(() -> firstFilter.destroy());
    }

    @Test
    void doFilter_withUserParameter_writesWelcomeMessage() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("user")).thenReturn("Alice");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        firstFilter.doFilter(mockRequest, mockResponse, mockFilterChain);

        // Assert
        verify(mockResponse).setContentType("text/plain");
        verify(mockFilterChain).doFilter(mockRequest, mockResponse);
        assertTrue(stringWriter.toString().contains("Alice"));
    }

    @Test
    void doFilter_withNullUser_usesDefaultUser() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("user")).thenReturn(null);
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        firstFilter.doFilter(mockRequest, mockResponse, mockFilterChain);

        // Assert
        verify(mockResponse).setContentType("text/plain");
        verify(mockFilterChain).doFilter(mockRequest, mockResponse);
        assertTrue(stringWriter.toString().contains("defaultUser"));
    }

    @Test
    void doFilter_setsContentTypePlain() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("user")).thenReturn("Bob");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        firstFilter.doFilter(mockRequest, mockResponse, mockFilterChain);

        // Assert
        verify(mockResponse).setContentType("text/plain");
    }

    @Test
    void doFilter_callsFilterChain() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("user")).thenReturn("TestUser");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        firstFilter.doFilter(mockRequest, mockResponse, mockFilterChain);

        // Assert
        verify(mockFilterChain, times(1)).doFilter(mockRequest, mockResponse);
    }

    @Test
    void doFilter_withEmptyUser_writesWelcomeWithEmptyUser() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("user")).thenReturn("");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        firstFilter.doFilter(mockRequest, mockResponse, mockFilterChain);

        // Assert
        String output = stringWriter.toString();
        assertTrue(output.contains("Welcome"));
    }
}
