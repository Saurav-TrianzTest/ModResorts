# ============================================================
# Stage 1: Builder
# ============================================================
FROM maven:3.9.4-eclipse-temurin-8 AS builder

WORKDIR /workspace

# Copy dependency descriptor first for layer caching
COPY pom.xml .

# Download all dependencies (cached layer)
RUN mvn dependency:go-offline -B

# Copy full source code
COPY src ./src
COPY WebContent ./WebContent

# Build the WAR (skip tests for Docker build)
RUN mvn clean package -DskipTests -B

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM eclipse-temurin:8-jdk

LABEL maintainer="ModResorts Team" \
      application="modresorts" \
      version="2.0.0"

# Set timezone
ENV TZ=UTC \
    JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UnlockExperimentalVMOptions" \
    SPRING_PROFILES_ACTIVE=docker \
    WEATHER_API_KEY="" \
    SERVER_DISPLAY_NAME="" \
    SERVER_FULL_NAME=""

# Install Tomcat 9 (supports Servlet 4.0 / Java EE 8)
ENV CATALINA_HOME=/opt/tomcat
ENV PATH=$CATALINA_HOME/bin:$PATH

RUN set -eux; \
    groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser; \
    mkdir -p /opt/tomcat; \
    TOMCAT_VERSION=9.0.85; \
    TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"; \
    apt-get update && apt-get install -y --no-install-recommends wget ca-certificates && \
    wget -q "$TOMCAT_URL" -O /tmp/tomcat.tar.gz && \
    tar -xzf /tmp/tomcat.tar.gz -C /opt/tomcat --strip-components=1 && \
    rm /tmp/tomcat.tar.gz && \
    apt-get remove -y wget && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && \
    rm -rf /opt/tomcat/webapps/ROOT \
           /opt/tomcat/webapps/examples \
           /opt/tomcat/webapps/docs \
           /opt/tomcat/webapps/host-manager \
           /opt/tomcat/webapps/manager && \
    chown -R appuser:appuser /opt/tomcat && \
    mkdir -p /app && chown -R appuser:appuser /app

# Copy WAR from builder stage
COPY --from=builder /workspace/target/modresorts-2.0.0.war /opt/tomcat/webapps/resorts.war

# Expose application port
EXPOSE 8080

USER appuser

# Start Tomcat
CMD ["catalina.sh", "run"]
