# Build stage: Maven on Java 8 builds the runnable war (spring-boot-maven-plugin repackage)
FROM maven:3.8.6-openjdk-8-slim AS builder
WORKDIR /workspace

# Dependencies first, so that this layer is cached until the pom changes
COPY pom.xml .
RUN mvn -B dependency:go-offline

# The war's web resources (WebContent) and the Java sources
COPY WebContent ./WebContent
COPY src ./src
RUN mvn -B clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:8-jdk

RUN groupadd --system --gid 1001 app \
    && useradd --system --uid 1001 --gid app --no-create-home app \
    && mkdir -p /app/logs \
    && chown -R app:app /app

WORKDIR /app
COPY --from=builder --chown=app:app /workspace/target/*.war app.war

ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Dfile.encoding=UTF-8 -Duser.timezone=UTC -Dlog4j2.formatMsgNoLookups=true" \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    SPRING_PROFILES_ACTIVE=prod \
    LOGGING_LEVEL_ROOT=INFO \
    PORT=8080

USER 1001

EXPOSE 8080

# exec: java, not the shell, is the first process and receives SIGTERM for a graceful shutdown
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.war"]
