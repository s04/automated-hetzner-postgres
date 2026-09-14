ARG POSTGRES_MAJOR=16
FROM postgres:${POSTGRES_MAJOR}-bookworm
# Use the PostgreSQL image's configured Debian/PGDG repositories.
RUN apt-get update \
    && apt-get install -y --no-install-recommends pgbackrest \
    && rm -rf /var/lib/apt/lists/*
