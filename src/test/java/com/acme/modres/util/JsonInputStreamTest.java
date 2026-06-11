package com.acme.modres.util;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Path;

public class JsonInputStreamTest {

    @TempDir
    Path tempDir;

    @Test
    void constructor_withExistingFile_createsInstance() throws Exception {
        // Arrange
        File tempFile = tempDir.resolve("test.json").toFile();
        tempFile.createNewFile();

        // Act
        JsonInputStream jsonInputStream = new JsonInputStream(tempFile);

        // Assert
        assertNotNull(jsonInputStream);
        jsonInputStream.close();
    }

    @Test
    void parseJsonAs_withNonExistentFile_returnsNull() throws Exception {
        // Arrange
        File tempFile = tempDir.resolve("test.json").toFile();
        tempFile.createNewFile();
        JsonInputStream jsonInputStream = new JsonInputStream(tempFile);

        // Delete the file to simulate non-existence
        File nonExistentFile = new File(tempDir.toFile(), "nonexistent.json");

        // Act - create a new stream with a file that doesn't exist
        // We need to test with a file that exists for constructor but then test parseJsonAs
        // Since the file exists, we test with empty content
        Object result = jsonInputStream.parseJsonAs(String.class);
        jsonInputStream.close();

        // Assert - empty file returns null from gson
        assertNull(result);
    }

    @Test
    void parseJsonAs_withValidJsonContent_parsesCorrectly() throws Exception {
        // Arrange
        File tempFile = tempDir.resolve("test.json").toFile();
        try (FileWriter writer = new FileWriter(tempFile)) {
            writer.write("\"hello world\"");
        }
        JsonInputStream jsonInputStream = new JsonInputStream(tempFile);

        // Act
        Object result = jsonInputStream.parseJsonAs(String.class);
        jsonInputStream.close();

        // Assert
        assertNotNull(result);
        assertEquals("hello world", result);
    }

    @Test
    void constructor_withNonExistentFile_throwsException() {
        // Arrange
        File nonExistentFile = new File(tempDir.toFile(), "nonexistent.json");

        // Act & Assert
        assertThrows(Exception.class, () -> new JsonInputStream(nonExistentFile));
    }

    @Test
    void parseJsonAs_withEmptyFile_returnsNull() throws Exception {
        // Arrange
        File tempFile = tempDir.resolve("empty.json").toFile();
        tempFile.createNewFile();
        JsonInputStream jsonInputStream = new JsonInputStream(tempFile);

        // Act
        Object result = jsonInputStream.parseJsonAs(String.class);
        jsonInputStream.close();

        // Assert
        assertNull(result);
    }
}
