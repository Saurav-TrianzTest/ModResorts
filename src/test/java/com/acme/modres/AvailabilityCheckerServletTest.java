package com.acme.modres;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import com.acme.modres.mbean.reservation.ReservationCheckerData;
import com.acme.modres.mbean.reservation.ReservationList;
import com.acme.modres.mbean.reservation.Reservation;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.reflect.Field;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class AvailabilityCheckerServletTest {

    private AvailabilityCheckerServlet servlet;

    @Mock
    private HttpServletRequest mockRequest;

    @Mock
    private HttpServletResponse mockResponse;

    @BeforeEach
    void setUp() throws Exception {
        servlet = new AvailabilityCheckerServlet();
        // Inject a ReservationCheckerData with an empty list
        ReservationList reservationList = new ReservationList();
        ReservationCheckerData checkerData = new ReservationCheckerData(reservationList);
        Field field = AvailabilityCheckerServlet.class.getDeclaredField("reservationCheckerData");
        field.setAccessible(true);
        field.set(servlet, checkerData);
    }

    @Test
    void doGet_withInvalidDate_returns500() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("date")).thenReturn("invalid-date");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        servlet.doGet(mockRequest, mockResponse);

        // Assert
        verify(mockResponse).setStatus(500);
    }

    @Test
    void doGet_withNullDate_returns500() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("date")).thenReturn(null);
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        servlet.doGet(mockRequest, mockResponse);

        // Assert
        verify(mockResponse).setStatus(500);
    }

    @Test
    void doGet_withValidDateAndNoReservations_returns200() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("date")).thenReturn("06/15/2024");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        servlet.doGet(mockRequest, mockResponse);

        // Assert
        verify(mockResponse).setStatus(200);
    }

    @Test
    void doGet_withValidDateAndNoReservations_returnsAvailableTrue() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("date")).thenReturn("06/15/2024");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        servlet.doGet(mockRequest, mockResponse);

        // Assert
        String output = stringWriter.toString();
        assertTrue(output.contains("true"));
    }

    @Test
    void doGet_withDateInReservationRange_returns201() throws Exception {
        // Arrange
        ReservationList reservationList = new ReservationList();
        reservationList.add(new Reservation("06/01/2024", "06/30/2024"));
        ReservationCheckerData checkerData = new ReservationCheckerData(reservationList);
        Field field = AvailabilityCheckerServlet.class.getDeclaredField("reservationCheckerData");
        field.setAccessible(true);
        field.set(servlet, checkerData);

        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("date")).thenReturn("06/15/2024");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        servlet.doGet(mockRequest, mockResponse);

        // Assert
        verify(mockResponse).setStatus(201);
    }

    @Test
    void doGet_setsContentTypeJson() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("date")).thenReturn("06/15/2024");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        servlet.doGet(mockRequest, mockResponse);

        // Assert
        verify(mockResponse).setContentType("application/json");
    }

    @Test
    void doPost_delegatesToDoGet() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("date")).thenReturn("06/15/2024");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        servlet.doPost(mockRequest, mockResponse);

        // Assert - doPost calls doGet, so same behavior
        verify(mockResponse).setContentType("application/json");
    }

    @Test
    void doGet_responseContainsAvailabilityJson() throws Exception {
        // Arrange
        StringWriter stringWriter = new StringWriter();
        PrintWriter printWriter = new PrintWriter(stringWriter);
        when(mockRequest.getParameter("date")).thenReturn("06/15/2024");
        when(mockResponse.getWriter()).thenReturn(printWriter);

        // Act
        servlet.doGet(mockRequest, mockResponse);

        // Assert
        String output = stringWriter.toString();
        assertTrue(output.contains("availability"));
    }
}
