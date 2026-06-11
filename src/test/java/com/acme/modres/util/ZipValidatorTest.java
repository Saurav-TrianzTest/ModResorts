package com.acme.modres.util;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.file.Path;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

public class ZipValidatorTest {

    @TempDir
    Path tempDir;

    private File createValidZipFile(String fileName) throws IOException {
        File zipFile = tempDir.resolve(fileName).toFile();
        try (ZipOutputStream zos = new ZipOutputStream(new FileOutputStream(zipFile))) {
            ZipEntry entry = new ZipEntry("test.txt");
            zos.putNextEntry(entry);
            zos.write("test content".getBytes());
            zos.closeEntry();
        }
        return zipFile;
    }

    private File createEmptyZipFile(String fileName) throws IOException {
        File zipFile = tempDir.resolve(fileName).toFile();
        try (ZipOutputStream zos = new ZipOutputStream(new FileOutputStream(zipFile))) {
            // Empty zip - no entries
        }
        return zipFile;
    }

    @Test
    void constructor_withValidZipFile_createsInstance() throws Throwable {
        // Arrange
        File zipFile = createValidZipFile("test.zip");

        // Act
        ZipValidator validator = new ZipValidator(zipFile);

        // Assert
        assertNotNull(validator);
        validator.close();
    }

    @Test
    void constructor_withNonZipFile_throwsException() throws Exception {
        // Arrange
        File nonZipFile = tempDir.resolve("test.txt").toFile();
        nonZipFile.createNewFile();

        // Act & Assert
        assertThrows(Exception.class, () -> new ZipValidator(nonZipFile));
    }

    @Test
    void isValid_withEmptyZip_returnsTrue() throws Throwable {
        // Arrange
        File zipFile = createEmptyZipFile("empty.zip");
        ZipValidator validator = new ZipValidator(zipFile);

        // Act
        boolean result = validator.isValid();
        validator.close();

        // Assert
        assertTrue(result);
    }

    @Test
    void isValid_withNonExistentFile_returnsFalse() throws Throwable {
        // Arrange - create a valid zip first for constructor, then delete it
        File zipFile = createEmptyZipFile("test.zip");
        ZipValidator validator = new ZipValidator(zipFile);

        // Delete the file
        zipFile.delete();

        // Act
        boolean result = validator.isValid();

        // Assert
        assertFalse(result);
    }

    @Test
    void isValid_withZipHavingEntries_returnsFalse() throws Throwable {
        // Arrange
        File zipFile = createValidZipFile("withentries.zip");
        ZipValidator validator = new ZipValidator(zipFile);

        // Act
        boolean result = validator.isValid();
        validator.close();

        // Assert
        // A zip with entries returns false (entries.hasMoreElements() is true, so it doesn't return true)
        assertFalse(result);
    }
}
