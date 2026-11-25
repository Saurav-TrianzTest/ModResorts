package com.acme.modres;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.http.HttpMessageConvertersAutoConfiguration;
import org.springframework.boot.autoconfigure.jackson.JacksonAutoConfiguration;
import org.springframework.boot.autoconfigure.web.servlet.DispatcherServletAutoConfiguration;
import org.springframework.boot.autoconfigure.web.servlet.WebMvcAutoConfiguration;
import org.springframework.boot.autoconfigure.web.servlet.error.ErrorMvcAutoConfiguration;
import org.springframework.boot.web.embedded.tomcat.TomcatServletWebServerFactory;
import org.springframework.boot.web.server.WebServerFactoryCustomizer;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.boot.web.servlet.ServletRegistrationBean;
import org.springframework.context.annotation.Bean;

/**
 * Standalone launcher: the application runs on Spring Boot's embedded Tomcat
 * instead of an IBM WebSphere server. The servlets and filters keep the URL
 * mappings they had from their annotations and from WEB-INF/web.xml (the
 * context path /resorts comes from application.properties, as WebSphere's
 * ibm-web-ext.xml gave it before). Spring MVC is not used, so Tomcat's default
 * servlet serves the pages.
 */
@SpringBootApplication(exclude = { DispatcherServletAutoConfiguration.class, WebMvcAutoConfiguration.class,
    ErrorMvcAutoConfiguration.class, JacksonAutoConfiguration.class, HttpMessageConvertersAutoConfiguration.class })
public class Application {

  public static void main(String[] args) {
    SpringApplication.run(Application.class, args);
  }

  @Bean
  public WebServerFactoryCustomizer<TomcatServletWebServerFactory> tomcatCustomizer() {
    return factory -> factory.addContextCustomizers(context -> context.addWelcomeFile("index.html"));
  }

  @Bean
  public ServletRegistrationBean<WeatherServlet> weatherServlet() {
    return new ServletRegistrationBean<>(new WeatherServlet(), "/weather", "/resorts/weather");
  }

  @Bean
  public ServletRegistrationBean<AvailabilityCheckerServlet> availabilityServlet() {
    return new ServletRegistrationBean<>(new AvailabilityCheckerServlet(), "/availability",
        "/resorts/availability");
  }

  @Bean
  public ServletRegistrationBean<WelcomeServlet> welcomeServlet() {
    return new ServletRegistrationBean<>(new WelcomeServlet(), "/welcome", "/resorts/welcome");
  }

  @Bean
  public ServletRegistrationBean<UpperServlet> upperServlet() {
    return new ServletRegistrationBean<>(new UpperServlet(), "/upper", "/resorts/upper");
  }

  @Bean
  public ServletRegistrationBean<LogoutServlet> logoutServlet() {
    return new ServletRegistrationBean<>(new LogoutServlet(), "/logout");
  }

  @Bean
  public ServletRegistrationBean<HealthServlet> healthServlet() {
    return new ServletRegistrationBean<>(new HealthServlet(), "/health");
  }

  @Bean
  public FilterRegistrationBean<FirstFilter> firstFilter() {
    FilterRegistrationBean<FirstFilter> registration = new FilterRegistrationBean<>(new FirstFilter());
    registration.addUrlPatterns("/welcome");
    registration.setOrder(1);
    return registration;
  }

  @Bean
  public FilterRegistrationBean<SecondFilter> secondFilter() {
    FilterRegistrationBean<SecondFilter> registration = new FilterRegistrationBean<>(new SecondFilter());
    registration.addUrlPatterns("/welcome");
    registration.setOrder(2);
    return registration;
  }
}
