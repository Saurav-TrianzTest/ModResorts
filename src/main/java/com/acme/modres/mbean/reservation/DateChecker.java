package com.acme.modres.mbean.reservation;

import java.text.ParseException;
import java.time.LocalDate;
import java.time.ZoneOffset;
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
        LocalDate fromDate = LocalDate.parse(reservation.getFromDate(), DateTimeFormatter.ofPattern(Constants.DATA_FORMAT).withZone(ZoneOffset.UTC));
        LocalDate toDate = LocalDate.parse(reservation.getToDate(), DateTimeFormatter.ofPattern(Constants.DATA_FORMAT).withZone(ZoneOffset.UTC));
        Date fromDateAsDate = Date.from(fromDate.atStartOfDay(ZoneOffset.UTC).toInstant());
        Date toDateAsDate = Date.from(toDate.atStartOfDay(ZoneOffset.UTC).toInstant());
        if (selectedDate.after(fromDateAsDate) && selectedDate.before(toDateAsDate)) {
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
