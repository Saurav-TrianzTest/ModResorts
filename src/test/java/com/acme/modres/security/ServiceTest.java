package com.acme.modres.security;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;

public class ServiceTest {

    private Service service;

    @BeforeEach
    void setUp() {
        service = new Service();
    }

    @Test
    void constructor_createsInstance() {
        assertNotNull(service);
    }

    @Test
    void operationConstant_hasCorrectValue() {
        assertEquals("my-operation", Service.OPERATION);
    }

    @Test
    void operation_doesNotThrowException() {
        assertDoesNotThrow(() -> service.operation());
    }

    @Test
    void operation_executesSuccessfully() {
        // Arrange
        ByteArrayOutputStream outContent = new ByteArrayOutputStream();
        PrintStream originalOut = System.out;
        System.setOut(new PrintStream(outContent));

        try {
            // Act
            service.operation();

            // Assert
            String output = outContent.toString();
            assertTrue(output.contains("Operation is executed"));
        } finally {
            System.setOut(originalOut);
        }
    }

    @Test
    void operationConstant_isNotNull() {
        assertNotNull(Service.OPERATION);
    }

    @Test
    void operationConstant_isNotEmpty() {
        assertFalse(Service.OPERATION.isEmpty());
    }
}
