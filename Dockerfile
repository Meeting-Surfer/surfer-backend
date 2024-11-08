# syntax=docker/dockerfile:1

################################################################################

# Create a stage for resolving and downloading dependencies.
FROM gradle:8.10-jdk23-alpine as deps

WORKDIR /build

# Copy the Gradle wrapper with executable permissions.
COPY --chmod=0755 gradlew gradlew
COPY gradle/ gradle/

# Download dependencies as a separate step to take advantage of Docker's caching.
COPY settings.gradle.kts ./
RUN gradle dependencies --no-daemon

################################################################################

# Create a stage for building the application based on the stage with downloaded dependencies.
FROM deps as package

WORKDIR /build

COPY app/ app/
RUN gradle build --no-daemon
RUN mv app/build/libs/app.jar app.jar


################################################################################

# Create a new stage for running the application that contains the minimal
# runtime dependencies for the application.
FROM eclipse-temurin:23-alpine AS final

# Create a non-privileged user that the app will run under.
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser
USER appuser

# Copy the executable from the "package" stage.
COPY --from=package /build/app.jar app.jar

EXPOSE 8080

ENTRYPOINT [ "java", "-jar", "app.jar" ]