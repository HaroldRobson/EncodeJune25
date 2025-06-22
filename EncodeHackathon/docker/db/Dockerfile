FROM postgres:15-alpine

# Copy initialization scripts
COPY *.sql /docker-entrypoint-initdb.d/

# Set proper permissions
RUN chmod -R 755 /docker-entrypoint-initdb.d/

# Expose PostgreSQL port
EXPOSE 5432
