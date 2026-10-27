package com.acme.modres.mbean;

import java.io.IOException;
import java.io.InputStream;

import com.acme.modres.mbean.reservation.ReservationList;
import com.acme.modres.util.JsonInputStream;

public final class IOUtils {

  public static InputStream getFileFromRelativePath(String path) {
    InputStream initialStream = null;
    try {
      initialStream = IOUtils.class.getClassLoader().getResourceAsStream(path);
      if (initialStream == null) {
        return null;
      }
      byte[] buffer = new byte[initialStream.available()];
      initialStream.read(buffer);
      return new java.io.ByteArrayInputStream(buffer);
    } catch (Exception e) {
      e.printStackTrace();
      if (initialStream != null) {
        try {
          initialStream.close();
        } catch (IOException ex) {
        }
      }
      return null;
    }
  }

  public static OpMetadataList getOpListFromConfig() {
    InputStream inputStream = getFileFromRelativePath("ops.json");
    if (inputStream == null) {
      return null;
    }
    try (JsonInputStream is = new JsonInputStream(inputStream)) {
      OpMetadataList opList = new OpMetadataList(); // empty default
      opList = (OpMetadataList) is.parseJsonAs(OpMetadataList.class);
      return opList;
    } catch (IOException e) {
      e.printStackTrace();
      return null;
    }
  }

  public static ReservationList getReservationListFromConfig() {
    InputStream inputStream = getFileFromRelativePath("reservations.json");
    if (inputStream == null) {
      return null;
    }
    try (JsonInputStream is = new JsonInputStream(inputStream)) {
      ReservationList reservationList = new ReservationList(); // empty default
      reservationList = (ReservationList) is.parseJsonAs(ReservationList.class);
      return reservationList;
    } catch (IOException e) {
      e.printStackTrace();
      return null;
    }
  }

}
