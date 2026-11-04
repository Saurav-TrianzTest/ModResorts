package com.acme.modres;

import java.io.File;

import org.apache.catalina.startup.Tomcat;

public class MainApplication {

  public static void main(String[] args) throws Exception {
    Tomcat tomcat = new Tomcat();
    tomcat.setPort(8080);

    String webappDir = new File("WebContent").getAbsolutePath();
    tomcat.addWebapp("", webappDir);

    tomcat.start();
    tomcat.getServer().await();
  }
}
