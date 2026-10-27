package com.acme.modres.util;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.zip.ZipEntry;
import java.util.zip.ZipException;
import java.util.zip.ZipInputStream;

public class ZipValidator {

  private final byte[] zipData;

  public ZipValidator(byte[] zipData) {
    this.zipData = zipData;
  }

  public boolean isValid() {
    if (zipData == null || zipData.length == 0) {
      return false;
    }
    try (ZipInputStream zipStream = new ZipInputStream(new ByteArrayInputStream(zipData))) {
      ZipEntry entry = zipStream.getNextEntry();
      return entry != null;
    } catch (ZipException e) {
      return false;
    } catch (IOException e) {
      return false;
    }
  }

}
