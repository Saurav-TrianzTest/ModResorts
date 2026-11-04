package com.acme.modres.mbean;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

import com.acme.modres.mbean.reservation.ReservationList;
import com.acme.modres.util.JsonInputStream;

public final class IOUtils {

  public static byte[] getBytesFromRelativePath(String path) {
    InputStream initialStream = null;
    ByteArrayOutputStream buffer = null;
    try {
      initialStream = IOUtils.class.getClassLoader().getResourceAsStream(path);
      if (initialStream == null) {
        return null;
      }
      buffer = new ByteArrayOutputStream();
      byte[] data = new byte[1024];
      int length;
      while ((length = initialStream.read(data)) >= 0) {
        buffer.write(data, 0, length);
      }
      return buffer.toByteArray();
    } catch (Exception e) {
      e.printStackTrace();
      return null;
    } finally {
      if (initialStream != null) {
        try {
          initialStream.close();
        } catch (IOException e) {
        }
      }
    }
  }

  public static OpMetadataList getOpListFromConfig() {
    byte[] data = getBytesFromRelativePath("ops.json");
    if (data == null) {
      return null;
    }
    try (JsonInputStream is = new JsonInputStream(data)) {
      OpMetadataList opList = new OpMetadataList(); // empty default
      opList = (OpMetadataList) is.parseJsonAs(OpMetadataList.class);
      return opList;
    } catch (IOException e) {
      e.printStackTrace();
      return null;
    }
  }

  public static ReservationList getReservationListFromConfig() {
    byte[] data = getBytesFromRelativePath("reservations.json");
    if (data == null) {
      return null;
    }
    try (JsonInputStream is = new JsonInputStream(data)) {
      ReservationList reservationList = new ReservationList(); // empty default
      reservationList = (ReservationList) is.parseJsonAs(ReservationList.class);
      return reservationList;
    } catch (IOException e) {
      e.printStackTrace();
      return null;
    }
  }

}
