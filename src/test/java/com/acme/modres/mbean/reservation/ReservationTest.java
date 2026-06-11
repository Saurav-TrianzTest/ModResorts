package com.acme.modres.mbean.reservation;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import static org.junit.jupiter.api.Assertions.*;

import java.util.ArrayList;
import java.util.List;

public class ReservationTest {

    @Test
    void defaultConstructor_createsInstance() {
        Reservation reservation = new Reservation();
        assertNotNull(reservation);
    }

    @Test
    void parameterizedConstructor_setsFromDate() {
        // Arrange & Act
        Reservation reservation = new Reservation("01/01/2024", "01/15/2024");

        // Assert
        assertEquals("01/01/2024", reservation.getFromDate());
    }

    @Test
    void parameterizedConstructor_setsToDate() {
        // Arrange & Act
        Reservation reservation = new Reservation("01/01/2024", "01/15/2024");

        // Assert
        assertEquals("01/15/2024", reservation.getToDate());
    }

    @Test
    void getFromDate_afterSetFromDate_returnsCorrectValue() {
        // Arrange
        Reservation reservation = new Reservation();

        // Act
        reservation.setFromDate("03/10/2024");

        // Assert
        assertEquals("03/10/2024", reservation.getFromDate());
    }

    @Test
    void getToDate_afterSetToDate_returnsCorrectValue() {
        // Arrange
        Reservation reservation = new Reservation();

        // Act
        reservation.setToDate("03/20/2024");

        // Assert
        assertEquals("03/20/2024", reservation.getToDate());
    }

    @Test
    void getFromDate_defaultConstructor_returnsNull() {
        Reservation reservation = new Reservation();
        assertNull(reservation.getFromDate());
    }

    @Test
    void getToDate_defaultConstructor_returnsNull() {
        Reservation reservation = new Reservation();
        assertNull(reservation.getToDate());
    }

    @Test
    void setFromDate_withNull_setsNull() {
        Reservation reservation = new Reservation("01/01/2024", "01/15/2024");
        reservation.setFromDate(null);
        assertNull(reservation.getFromDate());
    }

    @Test
    void setToDate_withNull_setsNull() {
        Reservation reservation = new Reservation("01/01/2024", "01/15/2024");
        reservation.setToDate(null);
        assertNull(reservation.getToDate());
    }

    @Test
    void setFromDate_overwritesExistingValue() {
        Reservation reservation = new Reservation("01/01/2024", "01/15/2024");
        reservation.setFromDate("06/01/2024");
        assertEquals("06/01/2024", reservation.getFromDate());
    }

    @Test
    void setToDate_overwritesExistingValue() {
        Reservation reservation = new Reservation("01/01/2024", "01/15/2024");
        reservation.setToDate("06/30/2024");
        assertEquals("06/30/2024", reservation.getToDate());
    }
}
