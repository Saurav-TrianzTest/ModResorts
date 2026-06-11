package com.acme.modres.security;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

public class SSLUtilsTest {

    @Test
    void constructor_createsInstance() {
        SSLUtils sslUtils = new SSLUtils();
        assertNotNull(sslUtils);
    }

    @Test
    void class_canBeInstantiated() {
        assertDoesNotThrow(() -> new SSLUtils());
    }

    @Test
    void instance_isNotNull() {
        SSLUtils sslUtils = new SSLUtils();
        assertNotNull(sslUtils);
    }
}
