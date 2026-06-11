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

import java.io.BufferedReader;
import java.io.PrintWriter;
import java.io.StringReader;
import java.io.StringWriter;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class SecondFilterTest {

    private SecondFilter secondFilter;

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
        secondFilter = new SecondFilter();
    }

    @Test
    void init_doesNotThrowException() throws Exception {
        assertDoesNotThrow(() -> secondFilter.init(mockFilterConfig));
    }

    @Test
    void destroy_doesNotThrowException() {
        assertDoesNotThrow(() -> secondFilter.destroy());
    }

    @Test
    void doFilter_withRequestBody_writesBodyToResponse() throws Exception {
        // Arrange
        String requestBody = "Hello";
        BufferedReader reader = new BufferedReader(new StringReader(requestBody));
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);

        when(mockRequest.getReader()).thenReturn(reader);
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        secondFilter.doFilter(mockRequest, mockResponse, mockFilterChain);

        // Assert
        verify(mockResponse).setContentType("text/plain");
        verify(mockFilterChain).doFilter(mockRequest, mockResponse);
        String output = stringWriter.toString();
        assertTrue(output.contains("Hello"));
        assertTrue(output.contains("to our site!"));
    }

    @Test
    void doFilter_withEmptyBody_writesEmptyBodyToResponse() throws Exception {
        // Arrange
        BufferedReader reader = new BufferedReader(new StringReader(""));
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);

        when(mockRequest.getReader()).thenReturn(reader);
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        secondFilter.doFilter(mockRequest, mockResponse, mockFilterChain);

        // Assert
        verify(mockResponse).setContentType("text/plain");
        verify(mockFilterChain).doFilter(mockRequest, mockResponse);
        assertTrue(stringWriter.toString().contains("to our site!"));
    }

    @Test
    void doFilter_setsContentTypePlain() throws Exception {
        // Arrange
        BufferedReader reader = new BufferedReader(new StringReader("test"));
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);

        when(mockRequest.getReader()).thenReturn(reader);
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        secondFilter.doFilter(mockRequest, mockResponse, mockFilterChain);

        // Assert
        verify(mockResponse).setContentType("text/plain");
    }

    @Test
    void doFilter_callsFilterChain() throws Exception {
        // Arrange
        BufferedReader reader = new BufferedReader(new StringReader("data"));
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);

        when(mockRequest.getReader()).thenReturn(reader);
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        secondFilter.doFilter(mockRequest, mockResponse, mockFilterChain);

        // Assert
        verify(mockFilterChain, times(1)).doFilter(mockRequest, mockResponse);
    }
}
