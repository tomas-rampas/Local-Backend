# Use Fedora as base image
FROM fedora:38

# Set environment variables for SQL Server
ENV ACCEPT_EULA=Y \
    MSSQL_PID=Developer \
    MSSQL_TCP_PORT=1433 \
    MSSQL_ENABLE_HADR=0

# Use build args for sensitive data without default values
# ARG MSSQL_SA_PASSWORD


# Update package lists and install dependencies
RUN dnf -y update && \
    # Install dependencies required for SQL Server
    dnf -y install curl openssl glibc hostname python3 libicu && \
    # Add Microsoft SQL Server repository
    curl -o /etc/yum.repos.d/mssql-server.repo https://packages.microsoft.com/config/rhel/9/mssql-server-2022.repo && \
    # Install SQL Server
    dnf -y install mssql-server --setopt=install_weak_deps=False && \
    # Add Microsoft tools repository
    curl -o /etc/yum.repos.d/msprod.repo https://packages.microsoft.com/config/rhel/9/prod.repo && \
    # Install SQL tools
    dnf -y install mssql-tools unixODBC-devel && \
    # Clean up
    dnf clean all && \
    rm -rf /var/cache/dnf

# Create user but let Docker handle volume directories
RUN groupadd -r mssql 2>/dev/null || true && \
    useradd -r -g mssql mssql 2>/dev/null || true

# Configure SQL Server with SA password and explicitly set Developer Edition
RUN /opt/mssql/bin/mssql-conf set sqlagent.enabled true && \
    /opt/mssql/bin/mssql-conf set telemetry.customerfeedback false

# Expose SQL Server port
EXPOSE 1433
EXPOSE 1434/udp

# Switch to non-root user
USER mssql

# Start SQL Server
CMD ["/opt/mssql/bin/sqlservr"]
