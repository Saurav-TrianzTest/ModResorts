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
import java.lang.reflect.Method;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class UpperServletTest {

    private UpperServlet upperServlet;

    @Mock
    private HttpServletRequest mockRequest;

    @Mock
    private HttpServletResponse mockResponse;

    @BeforeEach
    void setUp() {
        upperServlet = new UpperServlet();
    }

    @Test
    void doGet_withInputParameter_returnsUpperCase() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("input")).thenReturn("hello");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        upperServlet.doGet(mockRequest, mockResponse);

        // Assert
        verify(mockResponse).setContentType("text/html");
        String output = stringWriter.toString();
        assertTrue(output.contains("HELLO"));
    }

    @Test
    void doGet_withNullInput_returnsEmptyUpperCase() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("input")).thenReturn(null);
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        upperServlet.doGet(mockRequest, mockResponse);

        // Assert
        verify(mockResponse).setContentType("text/html");
        String output = stringWriter.toString();
        assertNotNull(output);
    }

    @Test
    void doGet_withHtmlSpecialChars_encodesHtml() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("input")).thenReturn("<script>");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        upperServlet.doGet(mockRequest, mockResponse);

        // Assert
        String output = stringWriter.toString();
        assertFalse(output.contains("<SCRIPT>"));
        assertTrue(output.contains("&lt;SCRIPT&gt;"));
    }

    @Test
    void doGet_withAmpersand_encodesAmpersand() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("input")).thenReturn("a&b");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        upperServlet.doGet(mockRequest, mockResponse);

        // Assert
        String output = stringWriter.toString();
        assertTrue(output.contains("&amp;"));
    }

    @Test
    void doGet_withDoubleQuote_encodesQuote() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("input")).thenReturn("say \"hello\"");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        upperServlet.doGet(mockRequest, mockResponse);

        // Assert
        String output = stringWriter.toString();
        assertTrue(output.contains("&quot;"));
    }

    @Test
    void doGet_withSingleQuote_encodesSingleQuote() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("input")).thenReturn("it's");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        upperServlet.doGet(mockRequest, mockResponse);

        // Assert
        String output = stringWriter.toString();
        assertTrue(output.contains("&#x27;"));
    }

    @Test
    void encodeHtml_withNullInput_returnsEmptyString() throws Exception {
        // Use reflection to test private method
        Method encodeHtml = UpperServlet.class.getDeclaredMethod("encodeHtml", String.class);
        encodeHtml.setAccessible(true);
        String result = (String) encodeHtml.invoke(upperServlet, (Object) null);
        assertEquals("", result);
    }

    @Test
    void encodeHtml_withNormalString_returnsUnchanged() throws Exception {
        Method encodeHtml = UpperServlet.class.getDeclaredMethod("encodeHtml", String.class);
        encodeHtml.setAccessible(true);
        String result = (String) encodeHtml.invoke(upperServlet, "HELLO");
        assertEquals("HELLO", result);
    }

    @Test
    void encodeHtml_withAllSpecialChars_encodesAll() throws Exception {
        Method encodeHtml = UpperServlet.class.getDeclaredMethod("encodeHtml", String.class);
        encodeHtml.setAccessible(true);
        String result = (String) encodeHtml.invoke(upperServlet, "<>&\"'");
        assertEquals("&lt;&gt;&amp;&quot;&#x27;", result);
    }

    @Test
    void doGet_setsContentTypeHtml() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("input")).thenReturn("test");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        upperServlet.doGet(mockRequest, mockResponse);

        // Assert
        verify(mockResponse).setContentType("text/html");
    }
}
