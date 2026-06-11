package com.acme.modres.mbean;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import static org.junit.jupiter.api.Assertions.*;

public class OpMetadataTest {

    private OpMetadata opMetadata;

    @BeforeEach
    void setUp() {
        opMetadata = new OpMetadata();
    }

    @Test
    void defaultConstructor_createsInstance() {
        assertNotNull(opMetadata);
    }

    @Test
    void parameterizedConstructor_setsAllFields() {
        // Arrange & Act
        OpMetadata op = new OpMetadata("myOp", "My description", "void", 1);

        // Assert
        assertEquals("myOp", op.getName());
        assertEquals("My description", op.getDescription());
        assertEquals("void", op.getType());
        assertEquals(1, op.getImpact());
    }

    @Test
    void getName_afterSetName_returnsCorrectValue() {
        // Act
        opMetadata.setName("testOperation");

        // Assert
        assertEquals("testOperation", opMetadata.getName());
    }

    @Test
    void getDescription_afterSetDescription_returnsCorrectValue() {
        // Act
        opMetadata.setDescription("Test description");

        // Assert
        assertEquals("Test description", opMetadata.getDescription());
    }

    @Test
    void getType_afterSetType_returnsCorrectValue() {
        // Act
        opMetadata.setType("java.lang.String");

        // Assert
        assertEquals("java.lang.String", opMetadata.getType());
    }

    @Test
    void getImpact_afterSetImpact_returnsCorrectValue() {
        // Act
        opMetadata.setImpact(2);

        // Assert
        assertEquals(2, opMetadata.getImpact());
    }

    @Test
    void getName_defaultConstructor_returnsNull() {
        assertNull(opMetadata.getName());
    }

    @Test
    void getDescription_defaultConstructor_returnsNull() {
        assertNull(opMetadata.getDescription());
    }

    @Test
    void getType_defaultConstructor_returnsNull() {
        assertNull(opMetadata.getType());
    }

    @Test
    void getImpact_defaultConstructor_returnsZero() {
        assertEquals(0, opMetadata.getImpact());
    }

    @Test
    void setName_withNull_setsNull() {
        opMetadata.setName(null);
        assertNull(opMetadata.getName());
    }

    @Test
    void setDescription_withNull_setsNull() {
        opMetadata.setDescription(null);
        assertNull(opMetadata.getDescription());
    }

    @Test
    void setType_withNull_setsNull() {
        opMetadata.setType(null);
        assertNull(opMetadata.getType());
    }

    @Test
    void setImpact_withNegativeValue_setsNegativeValue() {
        opMetadata.setImpact(-1);
        assertEquals(-1, opMetadata.getImpact());
    }
}
