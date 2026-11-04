FROM maven:3.9.4-eclipse-temurin-8 AS builder

WORKDIR /workspace

COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src/ src/
COPY WebContent/ WebContent/
RUN mvn clean package -DskipTests

FROM eclipse-temurin:8-jdk

ENV TZ=UTC \
    JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0" \
    CATALINA_HOME=/opt/tomcat \
    CATALINA_BASE=/opt/tomcat

COPY --from=tomcat:8.5.95-jdk8-openjdk /usr/local/tomcat /opt/tomcat

RUN rm -rf /opt/tomcat/webapps/ROOT

COPY --from=builder /workspace/target/*.war /opt/tomcat/webapps/ROOT.war

EXPOSE 8080

USER 1000

ENTRYPOINT ["sh", "-c", "exec $CATALINA_HOME/bin/catalina.sh run"]
