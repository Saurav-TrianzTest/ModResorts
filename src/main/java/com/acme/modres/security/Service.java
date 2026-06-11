package com.acme.modres.security;

public class Service {
  public static final String OPERATION = "my-operation";

  public void operation() {
    // SecurityManager is deprecated for removal in Java 17 (JEP 411).
    // Removed usage of System.getSecurityManager() as it is deprecated
    // and will be removed in a future Java release.
    // If access control is needed, use alternative security mechanisms
    // such as module system, JAAS, or application-level authorization.
    System.out.println("Operation is executed");
  }
}
