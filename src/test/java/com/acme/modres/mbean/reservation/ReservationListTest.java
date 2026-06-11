package com.acme.modres.mbean.reservation;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import static org.junit.jupiter.api.Assertions.*;

import java.util.ArrayList;
import java.util.List;

public class ReservationListTest {

    private ReservationList reservationList;

    @BeforeEach
    void setUp() {
        reservationList = new ReservationList();
    }

    @Test
    void defaultConstructor_createsEmptyList() {
        assertNotNull(reservationList);
        assertNotNull(reservationList.getReservations());
        assertTrue(reservationList.getReservations().isEmpty());
    }

    @Test
    void parameterizedConstructor_setsReservations() {
        // Arrange
        List<Reservation> reservations = new ArrayList<>();
        reservations.add(new Reservation("01/01/2024", "01/10/2024"));
        reservations.add(new Reservation("02/01/2024", "02/10/2024"));

        // Act
        ReservationList list = new ReservationList(reservations);

        // Assert
        assertEquals(2, list.getReservations().size());
    }

    @Test
    void add_singleReservation_listHasOneElement() {
        // Arrange
        Reservation reservation = new Reservation("01/01/2024", "01/10/2024");

        // Act
        reservationList.add(reservation);

        // Assert
        assertEquals(1, reservationList.getReservations().size());
    }

    @Test
    void add_multipleReservations_listHasCorrectCount() {
        // Arrange & Act
        reservationList.add(new Reservation("01/01/2024", "01/10/2024"));
        reservationList.add(new Reservation("02/01/2024", "02/10/2024"));
        reservationList.add(new Reservation("03/01/2024", "03/10/2024"));

        // Assert
        assertEquals(3, reservationList.getReservations().size());
    }

    @Test
    void getReservations_returnsCorrectReservation() {
        // Arrange
        Reservation reservation = new Reservation("05/01/2024", "05/15/2024");
        reservationList.add(reservation);

        // Act
        List<Reservation> result = reservationList.getReservations();

        // Assert
        assertNotNull(result);
        assertEquals("05/01/2024", result.get(0).getFromDate());
        assertEquals("05/15/2024", result.get(0).getToDate());
    }

    @Test
    void getReservations_emptyList_returnsEmptyList() {
        List<Reservation> result = reservationList.getReservations();
        assertNotNull(result);
        assertTrue(result.isEmpty());
    }

    @Test
    void parameterizedConstructor_withEmptyList_createsEmptyList() {
        // Arrange
        List<Reservation> emptyList = new ArrayList<>();

        // Act
        ReservationList list = new ReservationList(emptyList);

        // Assert
        assertNotNull(list.getReservations());
        assertTrue(list.getReservations().isEmpty());
    }
}
