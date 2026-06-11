package com.acme.modres.mbean;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import static org.junit.jupiter.api.Assertions.*;

import javax.management.MBeanOperationInfo;

public class DMBeanUtilsTest {

    @Test
    void getOps_withNullOpList_returnsNull() {
        // Act
        MBeanOperationInfo[] result = DMBeanUtils.getOps(null);

        // Assert
        assertNull(result);
    }

    @Test
    void getOps_withEmptyOpList_returnsNull() {
        // Arrange
        OpMetadataList emptyList = new OpMetadataList();

        // Act
        MBeanOperationInfo[] result = DMBeanUtils.getOps(emptyList);

        // Assert
        assertNull(result);
    }

    @Test
    void getOps_withOpListHavingNullInternalList_returnsNull() {
        // Arrange
        OpMetadataList opList = new OpMetadataList();
        opList.setOpMetadatList(null);

        // Act
        MBeanOperationInfo[] result = DMBeanUtils.getOps(opList);

        // Assert
        assertNull(result);
    }

    @Test
    void getOps_withSingleOperation_returnsArrayOfOne() {
        // Arrange
        OpMetadataList opList = new OpMetadataList();
        OpMetadata op = new OpMetadata("testOp", "Test operation", "void", MBeanOperationInfo.ACTION);
        opList.add(op);

        // Act
        MBeanOperationInfo[] result = DMBeanUtils.getOps(opList);

        // Assert
        assertNotNull(result);
        assertEquals(1, result.length);
    }

    @Test
    void getOps_withMultipleOperations_returnsCorrectCount() {
        // Arrange
        OpMetadataList opList = new OpMetadataList();
        opList.add(new OpMetadata("op1", "Operation 1", "void", MBeanOperationInfo.ACTION));
        opList.add(new OpMetadata("op2", "Operation 2", "String", MBeanOperationInfo.INFO));
        opList.add(new OpMetadata("op3", "Operation 3", "int", MBeanOperationInfo.UNKNOWN));

        // Act
        MBeanOperationInfo[] result = DMBeanUtils.getOps(opList);

        // Assert
        assertNotNull(result);
        assertEquals(3, result.length);
    }

    @Test
    void getOps_withOperation_setsCorrectName() {
        // Arrange
        OpMetadataList opList = new OpMetadataList();
        opList.add(new OpMetadata("myOperation", "My operation", "void", MBeanOperationInfo.ACTION));

        // Act
        MBeanOperationInfo[] result = DMBeanUtils.getOps(opList);

        // Assert
        assertNotNull(result);
        assertEquals("myOperation", result[0].getName());
    }

    @Test
    void getOps_withOperation_setsCorrectDescription() {
        // Arrange
        OpMetadataList opList = new OpMetadataList();
        opList.add(new OpMetadata("op", "My description", "void", MBeanOperationInfo.ACTION));

        // Act
        MBeanOperationInfo[] result = DMBeanUtils.getOps(opList);

        // Assert
        assertNotNull(result);
        assertEquals("My description", result[0].getDescription());
    }

    @Test
    void getOps_withOperation_setsCorrectReturnType() {
        // Arrange
        OpMetadataList opList = new OpMetadataList();
        opList.add(new OpMetadata("op", "desc", "java.lang.String", MBeanOperationInfo.INFO));

        // Act
        MBeanOperationInfo[] result = DMBeanUtils.getOps(opList);

        // Assert
        assertNotNull(result);
        assertEquals("java.lang.String", result[0].getReturnType());
    }
}
