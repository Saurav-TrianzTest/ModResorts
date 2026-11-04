package com.acme.modres.mbean.reservation;

import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Date;
import java.util.List;

import com.acme.modres.Constants;

public class DateChecker implements Runnable {
  ReservationCheckerData data;
  List<Reservation> reservations;

  public DateChecker(ReservationCheckerData data) {
    this.data = data;
    this.reservations = data.getReservationList().getReservations();
  }

  public void run() {
    for (int i = 0; i < reservations.size(); i++) {
      Reservation reservation = reservations.get(i);
      Date selectedDate = data.getSelectedDate();

      try {
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern(Constants.DATA_FORMAT).withZone(ZoneId.of("UTC"));
        Date fromDate = Date.from(LocalDate.parse(reservation.getFromDate(), formatter).atStartOfDay(ZoneId.of("UTC")).toInstant());
        Date toDate = Date.from(LocalDate.parse(reservation.getToDate(), formatter).atStartOfDay(ZoneId.of("UTC")).toInstant());
        if (selectedDate.after(fromDate) && selectedDate.before(toDate)) {
          data.setAvailablility(false);
          break;
        }
      } catch (Exception ex) {
        ex.printStackTrace();
      }
    }
    data.setAvailablility(true);
  }
}
