package com.acme.modres.util;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.zip.ZipEntry;
import java.util.zip.ZipException;
import java.util.zip.ZipInputStream;

public class ZipValidator extends ZipInputStream {

  private byte[] data;

  public ZipValidator(byte[] data) throws ZipException, IOException {
    super(new ByteArrayInputStream(data));
    this.data = data;
  }

  public boolean isValid() throws Throwable {
    if (data == null || data.length == 0) {
      return false;
    }
    ZipInputStream zipStream = new ZipInputStream(new ByteArrayInputStream(data));
    try {
      ZipEntry entry = zipStream.getNextEntry();
      if (entry == null) {
        return true;
      }
      return false;
    } finally {
      zipStream.close();
    }
  }

}
