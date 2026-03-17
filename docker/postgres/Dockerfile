FROM postgres:16-alpine

# Set locale
ENV LANG=es_ES.utf8

# Copy initialization script
COPY init.sql /docker-entrypoint-initdb.d/

# The init.sql script will run automatically when the container is first created
