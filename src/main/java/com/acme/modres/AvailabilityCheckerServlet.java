package com.acme.modres;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintWriter;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Date;
import java.util.List;
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

import com.acme.modres.util.ZipValidator;
import software.amazon.awssdk.core.exception.SdkException;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

@WebServlet({ "/resorts/availability" })
public class AvailabilityCheckerServlet extends HttpServlet {
  private static final long serialVersionUID = 1L;

  private static final Logger logger = Logger.getLogger(AvailabilityCheckerServlet.class.getName());

  private static InitialContext context;

  private ReservationCheckerData reservationCheckerData;

  private static final DateTimeFormatter DATE_FORMATTER =
      DateTimeFormatter.ofPattern(Constants.DATA_FORMAT).withZone(ZoneOffset.UTC);

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

      for (Reservation reservation : reservations) {
        try {
          LocalDate fromDate = LocalDate.parse(reservation.getFromDate(), DATE_FORMATTER);
          LocalDate toDate = LocalDate.parse(reservation.getToDate(), DATE_FORMATTER);
          Date selectedDate = reservationCheckerData.getSelectedDate();

          Date fromDateAsDate = Date.from(fromDate.atStartOfDay(ZoneOffset.UTC).toInstant());
          Date toDateAsDate = Date.from(toDate.atStartOfDay(ZoneOffset.UTC).toInstant());

          if (selectedDate.after(fromDateAsDate) && selectedDate.before(toDateAsDate)) {
            isAvailible = false;
            break;
          }
        } catch (Exception ex) {
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
    InputStream fileToZip = IOUtils.getFileFromRelativePath("reservations.json");
    String s3Bucket = System.getenv("APP_S3_BUCKET");
    String s3Key = "reservations/reservations.zip";

    try {
      ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
      ZipOutputStream zipOut = new ZipOutputStream(byteArrayOutputStream);

      ZipEntry zipEntry = new ZipEntry("reservations.json");
      zipOut.putNextEntry(zipEntry);

      byte[] bytes = new byte[1024];
      int length;
      while ((length = fileToZip.read(bytes)) >= 0) {
        zipOut.write(bytes, 0, length);
      }
      zipOut.closeEntry();

      zipOut.close();
      fileToZip.close();

      byte[] zipBytes = byteArrayOutputStream.toByteArray();

      // verify zip
      try (InputStream zipInputStream = new java.io.ByteArrayInputStream(zipBytes)) {
        ZipValidator zipValidator = new ZipValidator(zipInputStream);
        if (zipValidator.isValid()) {
          // Upload to S3
          S3Client s3Client = S3Client.create();
          try {
            PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(s3Bucket)
                .key(s3Key)
                .contentType("application/zip")
                .build();
            s3Client.putObject(putRequest, RequestBody.fromBytes(zipBytes));
          } finally {
            s3Client.close();
          }
          return 0;
        }
      }
    } catch (IOException e) {
      // TODO Auto-generated catch block
      e.printStackTrace();
    } catch (SdkException e) {
      e.printStackTrace();
    } catch (Throwable e) {
      // TODO Auto-generated catch block
      e.printStackTrace();
    }
    return -1;
  }

}