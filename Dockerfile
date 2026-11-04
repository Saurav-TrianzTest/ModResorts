FROM maven:3.8.6-openjdk-8-slim AS builder

WORKDIR /workspace

COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src/ src/
COPY WebContent/ WebContent/

RUN mvn clean package -DskipTests

# Download and extract Apache Tomcat 8.5 for Java 8
RUN curl -L -o /tmp/tomcat.tar.gz https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.92/bin/apache-tomcat-8.5.92.tar.gz && \
    tar -xzf /tmp/tomcat.tar.gz -C /opt/ && \
    ln -s /opt/apache-tomcat-8.5.92 /opt/tomcat && \
    rm -f /tmp/tomcat.tar.gz

# Remove the default Tomcat manager and host-manager apps to save space
RUN rm -rf /opt/tomcat/webapps/manager /opt/tomcat/webapps/host-manager

# Copy the WAR into Tomcat webapps as ROOT.war
RUN cp /workspace/target/modresorts-2.0.0.war /opt/tomcat/webapps/ROOT.war

FROM eclipse-temurin:8-jdk

ENV CATALINA_HOME=/opt/tomcat
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
ENV TZ=UTC
ENV JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8 -Duser.timezone=UTC"

COPY --from=builder /opt/tomcat /opt/tomcat
COPY --from=builder /workspace/target/modresorts-2.0.0.war /opt/tomcat/webapps/ROOT.war

RUN addgroup --system modresorts && \
    adduser --system --ingroup modresorts modresorts && \
    chown -R modresorts:modresorts /opt/tomcat

USER modresorts

EXPOSE 8080

ENTRYPOINT ["/opt/tomcat/bin/catalina.sh", "run"]
