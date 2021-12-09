FROM pgrouting/pgrouting:12-3.1-3.1.3

# Adding template sql procedure file
COPY sql_templates/*.sh /usr/local/bin/

# Change own user
RUN chown postgres:postgres /usr/local/bin/ && \
    chmod +x /usr/local/bin/generate_routeProcedures.sh && \
    chmod +x /usr/local/bin/generate_utilities.sh && \
    chmod +x /usr/local/bin/generate_isochroneProcedures.sh

# Create database add  procedures
COPY scripts/add_procedures.sh /docker-entrypoint-initdb.d/