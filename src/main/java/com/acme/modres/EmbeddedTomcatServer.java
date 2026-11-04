package com.acme.modres;

import org.apache.catalina.startup.Tomcat;
import java.io.File;

public class EmbeddedTomcatServer {

  public static void main(String[] args) throws Exception {
    String port = System.getenv("PORT");
    int serverPort = 8080;
    if (port != null && !port.isEmpty()) {
      serverPort = Integer.parseInt(port);
    }

    Tomcat tomcat = new Tomcat();
    tomcat.setPort(serverPort);

    String docBase = new File("WebContent").getAbsolutePath();
    tomcat.addWebapp("", docBase);

    tomcat.start();
    tomcat.getServer().await();
  }
}
