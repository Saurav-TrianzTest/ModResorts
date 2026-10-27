package com.acme.modres;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintWriter;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.TimeZone;
import java.util.logging.Logger;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import javax.naming.InitialContext;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import com.acme.modres.mbean.IOUtils;
import com.acme.modres.mbean.reservation.DateChecker;
import com.acme.modres.mbean.reservation.ReservationCheckerData;
import com.acme.modres.mbean.reservation.Reservation;

import com.acme.modres.util.BlobStorageClient;
import com.acme.modres.util.ZipValidator;

@WebServlet({ "/resorts/availability" })
public class AvailabilityCheckerServlet extends HttpServlet {
  private static final long serialVersionUID = 1L;

  private static final Logger logger = Logger.getLogger(AvailabilityCheckerServlet.class.getName());

  private static InitialContext context;

  private ReservationCheckerData reservationCheckerData;

  @Override
  public void init() {
    // load reserved dates
    this.reservationCheckerData = new ReservationCheckerData(IOUtils.getReservationListFromConfig());
  }

  @Override
  protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException, ServletException {

    String methodName = "doGet";
    logger.entering(AvailabilityCheckerServlet.class.getName(), methodName);
    int statusCode = 200;

    String selectedDateStr = request.getParameter("date");
    boolean parsedDate = reservationCheckerData.setSelectedDate(selectedDateStr);
    if (!parsedDate || reservationCheckerData.getReservationList() == null) {
      statusCode = 500;
      reservationCheckerData.setAvailablility(false);
    } else {
      List<Reservation> reservations = reservationCheckerData.getReservationList().getReservations();
      boolean isAvailible = true;

      SimpleDateFormat sdf = new SimpleDateFormat(Constants.DATA_FORMAT);
      sdf.setTimeZone(TimeZone.getTimeZone("UTC"));
      for (Reservation reservation : reservations) {
        try {
          Date fromDate = sdf.parse(reservation.getFromDate());
          Date toDate = sdf.parse(reservation.getToDate());
          Date selectedDate = reservationCheckerData.getSelectedDate();

          if (selectedDate.after(fromDate) && selectedDate.before(toDate)) {
            isAvailible = false;
            break;
          }
        } catch (ParseException ex) {
          ex.printStackTrace();
        }
      }

      reservationCheckerData.setAvailablility(isAvailible);

      // Adjust the status code based on availability
      if (!isAvailible) {
        statusCode = 201;
      }
    }

    // Send the response
    PrintWriter out = response.getWriter();
    response.setContentType("application/json");
    response.setCharacterEncoding("UTF-8");
    out.print("{\"availability\": \"" + String.valueOf(reservationCheckerData.isAvailible()) + "\"}");
    response.setStatus(statusCode);
  }

  /**
   * Returns the weather information for a given city
   */
  protected void doPost(HttpServletRequest request, HttpServletResponse response)
      throws ServletException, IOException {

    doGet(request, response);
  }

  protected int exportRevervations(String selectedDateStr) {
    String blobName = "reservations-" + System.currentTimeMillis() + ".zip";
    try {
      // Read reservation data from classpath resource (no local file dependency)
      InputStream reservationsStream = IOUtils.getFileFromRelativePath("reservations.json");
      if (reservationsStream == null) {
        logger.severe("Could not read reservations.json from classpath");
        return -1;
      }

      byte[] reservationsData;
      try (ByteArrayOutputStream buffer = new ByteArrayOutputStream()) {
        byte[] data = new byte[1024];
        int length;
        while ((length = reservationsStream.read(data)) != -1) {
          buffer.write(data, 0, length);
        }
        reservationsData = buffer.toByteArray();
      } finally {
        reservationsStream.close();
      }

      // Create zip in memory
      ByteArrayOutputStream zipBuffer = new ByteArrayOutputStream();
      try (ZipOutputStream zipOut = new ZipOutputStream(zipBuffer)) {
        ZipEntry zipEntry = new ZipEntry("reservations.json");
        zipOut.putNextEntry(zipEntry);
        zipOut.write(reservationsData);
        zipOut.closeEntry();
      }

      // Upload zip to Azure Blob Storage
      byte[] zipData = zipBuffer.toByteArray();
      BlobStorageClient blobClient = BlobStorageClient.getInstance();
      blobClient.uploadBlob(blobName, zipData);

      // Verify zip integrity from the in-memory data
      ZipValidator zipValidator = new ZipValidator(zipData);
      if (zipValidator.isValid()) {
        return 0;
      }
    } catch (Exception e) {
      e.printStackTrace();
    }
    return -1;
  }

}
