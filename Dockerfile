# Stage 1: Build stage
FROM maven:3.8.6-openjdk-8-slim AS builder
WORKDIR /workspace

# Copy pom.xml and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build
COPY src/ src/
COPY WebContent/ WebContent/
RUN mvn clean package -DskipTests

# Stage 2: Runtime stage
FROM amazoncorretto:8
WORKDIR /app

# Download and extract Tomcat 8 (compatible with Java 8 and Servlet 3.1)
ENV TOMCAT_VERSION 8.5.97
ADD https://archive.apache.org/dist/tomcat/tomcat-8/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz /tmp/tomcat.tar.gz
RUN tar -xzf /tmp/tomcat.tar.gz -C /opt && \
    ln -s /opt/apache-tomcat-${TOMCAT_VERSION} /opt/tomcat && \
    rm -rf /opt/tomcat/webapps/* && \
    rm /tmp/tomcat.tar.gz

# Copy the WAR file to Tomcat webapps as ROOT
COPY --from=builder /workspace/target/*.war /opt/tomcat/webapps/ROOT.war

# Create non-root user
RUN groupadd -r tomcat && useradd -r -g tomcat -d /app tomcat && \
    chown -R tomcat:tomcat /opt/tomcat

# Environment variables
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0" \
    CATALINA_OPTS="" \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Expose Tomcat HTTP port
EXPOSE 8080

# Health check endpoint is served by the application on /health
# The platform probes http://localhost:8080/health

USER tomcat

ENTRYPOINT ["/opt/tomcat/bin/catalina.sh", "run"]
