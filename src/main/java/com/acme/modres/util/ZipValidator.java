package com.acme.modres.util;

import java.io.IOException;
import java.io.InputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipException;
import java.util.zip.ZipInputStream;

public class ZipValidator {

  private InputStream inputStream;

  public ZipValidator(InputStream inputStream) {
    this.inputStream = inputStream;
  }

  public boolean isValid() throws Throwable {
    if (inputStream != null) {
      ZipInputStream zipStream = null;
      try {
        zipStream = new ZipInputStream(inputStream);
        ZipEntry entry = zipStream.getNextEntry();
        if (entry == null) {
          return true;
        }
        return true;
      } finally {
        if (zipStream != null) {
          try {
            zipStream.close();
          } catch (IOException e) {
          }
        }
      }
    }
    return false;
  }

}
