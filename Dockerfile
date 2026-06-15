# ============================================================
# Stage 1: Builder
# ============================================================
FROM maven:3.9.4-eclipse-temurin-8 AS builder

WORKDIR /workspace

# Copy pom.xml first for dependency caching
COPY pom.xml .

# Download dependencies (layer cache)
RUN mvn dependency:go-offline -B

# Copy full project source
COPY src ./src
COPY WebContent ./WebContent

# Build the WAR artifact
RUN mvn clean package -DskipTests -B

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM eclipse-temurin:8-jdk

LABEL maintainer="ModResorts Team" \
      application="modresorts" \
      version="2.0.0"

# Set timezone
ENV TZ=UTC

# Create non-root user for security
RUN groupadd -r appgroup && useradd -r -g appgroup -d /app -s /sbin/nologin appuser

WORKDIR /app

# Copy the WAR from builder stage
COPY --from=builder /workspace/target/modresorts-2.0.0.war app.war

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

USER appuser

# Expose application port
EXPOSE 8080

# JVM options for container awareness
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions -Djava.security.egd=file:/dev/./urandom"

# Environment variables for application configuration
ENV WEATHER_API_KEY=""
ENV SERVER_DISPLAY_NAME="modresorts-server"
ENV SERVER_FULL_NAME="modresorts-server/default"
ENV JNDI_PROVIDER_URL=""

# Entry point - run with embedded server (java -jar) or servlet container
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.war"]
