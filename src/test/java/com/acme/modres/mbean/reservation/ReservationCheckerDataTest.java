package com.acme.modres.mbean.reservation;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import static org.junit.jupiter.api.Assertions.*;

import java.util.Date;

public class ReservationCheckerDataTest {

    private ReservationCheckerData checkerData;
    private ReservationList reservationList;

    @BeforeEach
    void setUp() {
        reservationList = new ReservationList();
        checkerData = new ReservationCheckerData(reservationList);
    }

    @Test
    void constructor_createsInstance() {
        assertNotNull(checkerData);
    }

    @Test
    void constructor_setsReservationList() {
        assertEquals(reservationList, checkerData.getReservationList());
    }

    @Test
    void constructor_defaultAvailabilityIsTrue() {
        assertTrue(checkerData.isAvailible());
    }

    @Test
    void getReservationList_returnsCorrectList() {
        assertNotNull(checkerData.getReservationList());
        assertEquals(reservationList, checkerData.getReservationList());
    }

    @Test
    void setSelectedDate_withValidDate_returnsTrue() {
        // Act
        boolean result = checkerData.setSelectedDate("01/15/2024");

        // Assert
        assertTrue(result);
    }

    @Test
    void setSelectedDate_withInvalidDate_returnsFalse() {
        // Act
        boolean result = checkerData.setSelectedDate("not-a-date");

        // Assert
        assertFalse(result);
    }

    @Test
    void setSelectedDate_withNullDate_returnsFalse() {
        // Act
        boolean result = checkerData.setSelectedDate(null);

        // Assert
        assertFalse(result);
    }

    @Test
    void setSelectedDate_withEmptyDate_returnsFalse() {
        // Act
        boolean result = checkerData.setSelectedDate("");

        // Assert
        assertFalse(result);
    }

    @Test
    void getSelectedDate_afterValidSetSelectedDate_returnsDate() {
        // Arrange
        checkerData.setSelectedDate("06/15/2024");

        // Act
        Date selectedDate = checkerData.getSelectedDate();

        // Assert
        assertNotNull(selectedDate);
    }

    @Test
    void getSelectedDate_beforeSetSelectedDate_returnsNull() {
        assertNull(checkerData.getSelectedDate());
    }

    @Test
    void setAvailablility_toFalse_isAvailibleReturnsFalse() {
        // Act
        checkerData.setAvailablility(false);

        // Assert
        assertFalse(checkerData.isAvailible());
    }

    @Test
    void setAvailablility_toTrue_isAvailibleReturnsTrue() {
        // Arrange
        checkerData.setAvailablility(false);

        // Act
        checkerData.setAvailablility(true);

        // Assert
        assertTrue(checkerData.isAvailible());
    }

    @Test
    void isAvailible_defaultIsTrue() {
        assertTrue(checkerData.isAvailible());
    }

    @Test
    void setSelectedDate_withValidDateFormat_parsesCorrectly() {
        // Act
        boolean result = checkerData.setSelectedDate("12/31/2024");

        // Assert
        assertTrue(result);
        assertNotNull(checkerData.getSelectedDate());
    }

    @Test
    void constructor_withNullReservationList_setsNullList() {
        // Act
        ReservationCheckerData data = new ReservationCheckerData(null);

        // Assert
        assertNull(data.getReservationList());
    }
}
