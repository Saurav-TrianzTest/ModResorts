package com.acme.modres.security;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

public class FakeX509TrustManagerTest {

    @Test
    void constructor_createsInstance() {
        FakeX509TrustManager trustManager = new FakeX509TrustManager();
        assertNotNull(trustManager);
    }

    @Test
    void instance_isNotNull() {
        FakeX509TrustManager trustManager = new FakeX509TrustManager();
        assertNotNull(trustManager);
    }

    @Test
    void class_canBeInstantiated() {
        assertDoesNotThrow(() -> new FakeX509TrustManager());
    }
}
