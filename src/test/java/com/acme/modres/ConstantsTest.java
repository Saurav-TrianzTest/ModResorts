package com.acme.modres;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

public class ConstantsTest {

    @Test
    void testCityConstants_Barcelona() {
        assertEquals("Barcelona", Constants.BARCELONA);
    }

    @Test
    void testCityConstants_Cork() {
        assertEquals("Cork", Constants.CORK);
    }

    @Test
    void testCityConstants_Miami() {
        assertEquals("Miami", Constants.MIAMI);
    }

    @Test
    void testCityConstants_SanFrancisco() {
        assertEquals("San_Francisco", Constants.SAN_FRANCISCO);
    }

    @Test
    void testCityConstants_Paris() {
        assertEquals("Paris", Constants.PARIS);
    }

    @Test
    void testCityConstants_LasVegas() {
        assertEquals("Las_Vegas", Constants.LAS_VEGAS);
    }

    @Test
    void testSupportedCities_NotNull() {
        assertNotNull(Constants.SUPPORTED_CITIES);
    }

    @Test
    void testSupportedCities_Length() {
        assertEquals(6, Constants.SUPPORTED_CITIES.length);
    }

    @Test
    void testSupportedCities_ContainsParis() {
        boolean found = false;
        for (String city : Constants.SUPPORTED_CITIES) {
            if ("Paris".equals(city)) {
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    @Test
    void testSupportedCities_ContainsLasVegas() {
        boolean found = false;
        for (String city : Constants.SUPPORTED_CITIES) {
            if ("Las_Vegas".equals(city)) {
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    @Test
    void testSupportedCities_ContainsSanFrancisco() {
        boolean found = false;
        for (String city : Constants.SUPPORTED_CITIES) {
            if ("San_Francisco".equals(city)) {
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    @Test
    void testSupportedCities_ContainsMiami() {
        boolean found = false;
        for (String city : Constants.SUPPORTED_CITIES) {
            if ("Miami".equals(city)) {
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    @Test
    void testSupportedCities_ContainsCork() {
        boolean found = false;
        for (String city : Constants.SUPPORTED_CITIES) {
            if ("Cork".equals(city)) {
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    @Test
    void testSupportedCities_ContainsBarcelona() {
        boolean found = false;
        for (String city : Constants.SUPPORTED_CITIES) {
            if ("Barcelona".equals(city)) {
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    @Test
    void testWeatherFileConstants_Barcelona() {
        assertEquals("barcelona.json", Constants.BACELONA_WEATHER_FILE);
    }

    @Test
    void testWeatherFileConstants_Cork() {
        assertEquals("cork.json", Constants.CORK_WEATHER_FILE);
    }

    @Test
    void testWeatherFileConstants_LasVegas() {
        assertEquals("nv.json", Constants.LAS_VEGAS_WEATHER_FILE);
    }

    @Test
    void testWeatherFileConstants_Miami() {
        assertEquals("miami.json", Constants.MIAMI_WEATHER_FILE);
    }

    @Test
    void testWeatherFileConstants_Paris() {
        assertEquals("paris.json", Constants.PARIS_WEATHER_FILE);
    }

    @Test
    void testWeatherFileConstants_SanFrancisco() {
        assertEquals("sanfran.json", Constants.SAN_FRANCESCO_WEATHER_FILE);
    }

    @Test
    void testWundergroundApiPrefix() {
        assertEquals("http://api.wunderground.com/api/", Constants.WUNDERGROUND_API_PREFIX);
    }

    @Test
    void testWundergroundApiPart() {
        assertEquals("/forecast/geolookup/conditions/q/", Constants.WUNDERGROUND_API_PART);
    }

    @Test
    void testDataFormat() {
        assertEquals("MM/dd/yyyy", Constants.DATA_FORMAT);
    }
}
