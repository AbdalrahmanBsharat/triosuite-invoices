# =====================================================================================
# Triosuite Invoices API — multi-stage image.
#
# Build:  docker build -t triosuite-invoices-api ./backend
# Run:    docker run --rm -p 8080:8080 --env-file .env triosuite-invoices-api
#
# The runtime stage is a JRE-only image running as a non-root user, sized for the 512 MB
# containers offered by free hosting tiers (see docs/DEPLOYMENT.md).
# =====================================================================================

# ------------------------------------------------------------------------------------
# Stage 1 — build with the committed Maven wrapper so the image needs no Maven install.
# ------------------------------------------------------------------------------------
FROM eclipse-temurin:21-jdk AS build

WORKDIR /build

# Dependency layer: copied first so it is cached until the POM actually changes.
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw -B -ntp dependency:go-offline

# Source layer.
COPY src/ src/
RUN ./mvnw -B -ntp clean package -DskipTests \
    && mv target/*.jar target/app.jar

# ------------------------------------------------------------------------------------
# Stage 2 — runtime.
# ------------------------------------------------------------------------------------
FROM eclipse-temurin:21-jre AS runtime

# curl is used by the container health check below.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Unprivileged account. Nothing in the image is writable by it except /tmp.
RUN groupadd --system --gid 10001 triosuite \
    && useradd --system --uid 10001 --gid triosuite --no-create-home triosuite

WORKDIR /app
COPY --from=build --chown=root:root --chmod=444 /build/target/app.jar /app/app.jar

# Tuned for a 512 MB container: serial GC and a single JIT tier keep both heap and
# start-up CPU low, which is what free tiers charge for.
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+UseSerialGC -Xss512k -XX:TieredStopAtLevel=1 -Djava.security.egd=file:/dev/./urandom"
ENV SPRING_PROFILES_ACTIVE=prod
ENV PORT=8080

USER triosuite:triosuite
EXPOSE 8080

# The platform health check hits the same endpoint; this one covers plain `docker run`.
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=5 \
    CMD curl --fail --silent "http://127.0.0.1:${PORT}/actuator/health" || exit 1

# `exec` so the JVM becomes PID 1 and receives SIGTERM for graceful shutdown.
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
