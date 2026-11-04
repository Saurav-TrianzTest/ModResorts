package com.acme.modres.util;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;

import com.google.gson.Gson;

public class JsonInputStream extends ByteArrayInputStream {

  private byte[] data;

  public JsonInputStream(byte[] data) {
    super(data);
    this.data = data;
  }

  public Object parseJsonAs(Class<?> cls) {
    JsonInputStream is = null;
    Object jsonObject = null;
    try {
      is = new JsonInputStream(data);
      Gson gson = new Gson();
      jsonObject = gson.fromJson(new java.io.InputStreamReader(is), cls);
    } catch (Exception e) {
      e.printStackTrace();
    } catch (Throwable e) {
      e.printStackTrace();
    } finally {
      if (is != null) {
        try {
          is.close();
        } catch (Exception e) {
          // closed successfully
          return jsonObject;
        }
      }
    }
    return jsonObject;
  }

}
