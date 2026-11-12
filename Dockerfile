# Stage 1: Build the WAR file and prepare Tomcat
FROM maven:3.9.4-eclipse-temurin-8 AS builder

WORKDIR /workspace

# Copy pom.xml first for dependency resolution
COPY pom.xml .

# Copy source code
COPY src/ src/
COPY WebContent/ WebContent/

# Build the WAR file, skipping tests
RUN mvn clean package -DskipTests

# Download and extract Apache Tomcat 8
RUN curl -L -o /tmp/tomcat.tar.gz https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.92/bin/apache-tomcat-8.5.92.tar.gz \
    && tar -xzf /tmp/tomcat.tar.gz -C /opt/ \
    && rm /tmp/tomcat.tar.gz \
    && rm -rf /opt/apache-tomcat-8.5.92/webapps/*

# Deploy the WAR to Tomcat as ROOT
RUN cp target/*.war /opt/apache-tomcat-8.5.92/webapps/ROOT.war

# Stage 2: Runtime
FROM eclipse-temurin:8-jdk

# Create a non-root user
RUN groupadd -r appuser -g 1001 && useradd -r -g appuser -u 1001 appuser

# Copy Tomcat from builder stage
COPY --from=builder /opt/apache-tomcat-8.5.92 /opt/tomcat

# Set ownership
RUN chown -R appuser:appuser /opt/tomcat

# Environment variables
ENV JAVA_HOME=/opt/java/openjdk \
    JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0" \
    CATALINA_HOME=/opt/tomcat \
    CATALINA_BASE=/opt/tomcat \
    TZ=UTC

# Expose the Tomcat HTTP port
EXPOSE 8080

# Switch to non-root user
USER 1001

# Start Tomcat (catalina.sh uses exec to start java as PID 1)
ENTRYPOINT ["/opt/tomcat/bin/catalina.sh", "run"]
