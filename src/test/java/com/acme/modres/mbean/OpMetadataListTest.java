package com.acme.modres.mbean;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import static org.junit.jupiter.api.Assertions.*;

import java.util.ArrayList;
import java.util.List;

public class OpMetadataListTest {

    private OpMetadataList opMetadataList;

    @BeforeEach
    void setUp() {
        opMetadataList = new OpMetadataList();
    }

    @Test
    void constructor_createsEmptyList() {
        assertNotNull(opMetadataList);
        assertNotNull(opMetadataList.getOpMetadatList());
        assertTrue(opMetadataList.getOpMetadatList().isEmpty());
    }

    @Test
    void add_singleItem_listHasOneElement() {
        // Arrange
        OpMetadata op = new OpMetadata("op1", "desc1", "void", 1);

        // Act
        opMetadataList.add(op);

        // Assert
        assertEquals(1, opMetadataList.getOpMetadatList().size());
    }

    @Test
    void add_multipleItems_listHasCorrectCount() {
        // Arrange
        opMetadataList.add(new OpMetadata("op1", "desc1", "void", 1));
        opMetadataList.add(new OpMetadata("op2", "desc2", "String", 2));
        opMetadataList.add(new OpMetadata("op3", "desc3", "int", 3));

        // Assert
        assertEquals(3, opMetadataList.getOpMetadatList().size());
    }

    @Test
    void getOpMetadatList_returnsCorrectList() {
        // Arrange
        OpMetadata op = new OpMetadata("testOp", "Test", "void", 0);
        opMetadataList.add(op);

        // Act
        List<OpMetadata> result = opMetadataList.getOpMetadatList();

        // Assert
        assertNotNull(result);
        assertEquals(1, result.size());
        assertEquals("testOp", result.get(0).getName());
    }

    @Test
    void setOpMetadatList_replacesExistingList() {
        // Arrange
        opMetadataList.add(new OpMetadata("old", "old desc", "void", 0));
        List<OpMetadata> newList = new ArrayList<>();
        newList.add(new OpMetadata("new1", "new desc1", "String", 1));
        newList.add(new OpMetadata("new2", "new desc2", "int", 2));

        // Act
        opMetadataList.setOpMetadatList(newList);

        // Assert
        assertEquals(2, opMetadataList.getOpMetadatList().size());
        assertEquals("new1", opMetadataList.getOpMetadatList().get(0).getName());
    }

    @Test
    void setOpMetadatList_withNull_setsNull() {
        // Act
        opMetadataList.setOpMetadatList(null);

        // Assert
        assertNull(opMetadataList.getOpMetadatList());
    }
}
