package com.acme.modres.util;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;

import com.google.gson.Gson;

public class JsonInputStream extends InputStream {

  private InputStream inputStream;

  public JsonInputStream(InputStream inputStream) {
    this.inputStream = inputStream;
  }

  public Object parseJsonAs(Class<?> cls) {
    if (inputStream != null) {
      Object jsonObject = null;
      try {
        Gson gson = new Gson();
        BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream));
        jsonObject = gson.fromJson(reader, cls);
        return jsonObject;
      } catch (Exception e) {
        e.printStackTrace();
      } catch (Throwable e) {
        e.printStackTrace();
      }
    }
    return null;
  }

  @Override
  public int read() throws IOException {
    if (inputStream != null) {
      return inputStream.read();
    }
    return -1;
  }

  @Override
  public void close() throws IOException {
    if (inputStream != null) {
      inputStream.close();
    }
  }

}
