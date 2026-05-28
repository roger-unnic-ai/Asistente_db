FROM pgvector/pgvector:pg16

# Install and generate es_ES.UTF-8 locale (required by postgresql.conf from existing data volumes)
RUN apt-get update && apt-get install -y --no-install-recommends locales \
    && echo "es_ES.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=es_ES.UTF-8
ENV LC_ALL=es_ES.UTF-8

# Copy initialization script
COPY init.sql /docker-entrypoint-initdb.d/

# The init.sql script will run automatically when the container is first created
