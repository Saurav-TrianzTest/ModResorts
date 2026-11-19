# Stage 1: Build stage
FROM maven:3.9.4-eclipse-temurin-8 AS builder
WORKDIR /workspace

# Copy pom.xml and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source and build
COPY src/ src/
COPY WebContent/ WebContent/
RUN mvn clean package -DskipTests -B

# Download Apache Tomcat for the runtime stage
RUN curl -sL https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.92/bin/apache-tomcat-8.5.92.tar.gz | tar -xz -C /opt/

# Stage 2: Runtime stage
FROM eclipse-temurin:8-jdk
LABEL maintainer="ModResorts"

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy Tomcat from builder
COPY --from=builder /opt/apache-tomcat-8.5.92 /opt/tomcat

# Copy the WAR file
COPY --from=builder /workspace/target/*.war /opt/tomcat/webapps/modresorts.war

# Set ownership
RUN chown -R appuser:appuser /opt/tomcat

# Environment settings
ENV TZ=UTC
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
ENV CATALINA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

# Expose Tomcat HTTP port
EXPOSE 8080

USER appuser

# Use exec form for proper signal handling
ENTRYPOINT ["/opt/tomcat/bin/catalina.sh", "run"]
