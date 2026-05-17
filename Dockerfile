FROM eclipse-temurin:17-jdk-jammy AS build

WORKDIR /app

COPY .mvn .mvn
COPY mvnw pom.xml ./

RUN sed -i 's/\r$//' mvnw && chmod +x mvnw
RUN ./mvnw -q -DskipTests dependency:go-offline

COPY src src

RUN ./mvnw -q clean package -DskipTests


FROM eclipse-temurin:17-jre-jammy

WORKDIR /app

RUN groupadd --system arkive \
    && useradd --system --gid arkive --home-dir /app --shell /usr/sbin/nologin arkive

COPY --from=build /app/target/*.jar app.jar

RUN chown -R arkive:arkive /app

USER arkive

EXPOSE 8080

ENV SPRING_PROFILES_ACTIVE=oracle

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
