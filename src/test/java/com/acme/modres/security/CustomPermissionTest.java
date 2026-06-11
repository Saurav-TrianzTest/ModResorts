package com.acme.modres.security;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

public class CustomPermissionTest {

    @Test
    void constructor_withName_createsInstance() {
        // Act
        CustomPermission permission = new CustomPermission("test.permission");

        // Assert
        assertNotNull(permission);
    }

    @Test
    void constructor_withNameAndActions_createsInstance() {
        // Act
        CustomPermission permission = new CustomPermission("test.permission", "read,write");

        // Assert
        assertNotNull(permission);
    }

    @Test
    void constructor_withName_setsName() {
        // Act
        CustomPermission permission = new CustomPermission("my.permission");

        // Assert
        assertEquals("my.permission", permission.getName());
    }

    @Test
    void constructor_withNameAndActions_setsName() {
        // Act
        CustomPermission permission = new CustomPermission("my.permission", "execute");

        // Assert
        assertEquals("my.permission", permission.getName());
    }

    @Test
    void implies_samePermission_returnsTrue() {
        // Arrange
        CustomPermission permission1 = new CustomPermission("test.permission");
        CustomPermission permission2 = new CustomPermission("test.permission");

        // Assert
        assertTrue(permission1.implies(permission2));
    }

    @Test
    void implies_differentPermission_returnsFalse() {
        // Arrange
        CustomPermission permission1 = new CustomPermission("test.permission");
        CustomPermission permission2 = new CustomPermission("other.permission");

        // Assert
        assertFalse(permission1.implies(permission2));
    }

    @Test
    void extendsBasicPermission() {
        // Arrange
        CustomPermission permission = new CustomPermission("test");

        // Assert
        assertTrue(permission instanceof java.security.BasicPermission);
    }

    @Test
    void constructor_withWildcardName_createsInstance() {
        // Act
        CustomPermission permission = new CustomPermission("test.*");

        // Assert
        assertNotNull(permission);
    }

    @Test
    void constructor_withEmptyActions_createsInstance() {
        // Act
        CustomPermission permission = new CustomPermission("test.permission", "");

        // Assert
        assertNotNull(permission);
    }
}
