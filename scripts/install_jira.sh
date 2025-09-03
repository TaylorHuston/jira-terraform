#!/bin/bash
set -e

# Log everything for debugging
exec > >(tee -a /var/log/user-data.log)
exec 2>&1

echo "==================================="
echo "Starting Jira 10.3 LTS installation"
echo "==================================="

# Wait for network and cloud-init to complete
sleep 30

# System updates
apt-get update && apt-get upgrade -y

# Install dependencies
apt-get install -y wget curl unzip fontconfig

# Install Java 17 (required for Jira 10.x)
# Using Eclipse Temurin (formerly AdoptOpenJDK)
wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg || { echo "ERROR: Failed to download Adoptium GPG key"; exit 1; }
echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/adoptium.list
apt-get update
apt-get install -y temurin-17-jdk

# Install PostgreSQL client for database connectivity
# Add PostgreSQL APT repository for newer versions
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg || { echo "ERROR: Failed to download PostgreSQL GPG key"; exit 1; }
echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list
apt-get update

# Install PostgreSQL client (will get latest available version)
echo "Installing PostgreSQL client..."
apt-get install -y postgresql-client

# Create jira user
useradd -m -d /opt/jira -s /bin/bash jira || echo "User already exists"

# Jira installation variables
JIRA_VERSION="10.3.10"
JIRA_HOME="/var/atlassian/application-data/jira"
JIRA_INSTALL="/opt/atlassian/jira"

# Verify Java installation
java -version
if [ $? -ne 0 ]; then
    echo "ERROR: Java 17 installation failed"
    exit 1
fi

# Create directories
mkdir -p $JIRA_HOME
mkdir -p $JIRA_HOME/logs
mkdir -p $JIRA_INSTALL
mkdir -p /var/log/jira

# Create /logs directory as fallback (Jira default GC log location)
mkdir -p /logs
chown jira:jira /logs
chmod 755 /logs

# Download and extract Jira
cd /tmp
echo "Downloading Jira Software 10.3.10.tar.gz..."
wget -O atlassian-jira-software-10.3.10.tar.gz \
    "https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-10.3.10.tar.gz" \
    || { echo "ERROR: Failed to download Jira"; exit 1; }

echo "Extracting Jira..."
tar -xzf atlassian-jira-software-10.3.10.tar.gz -C $JIRA_INSTALL --strip-components=1

# Set permissions
chown -R jira:jira $JIRA_HOME
chown -R jira:jira $JIRA_INSTALL
chown -R jira:jira /var/log/jira
chmod 755 $JIRA_HOME/logs
chmod 755 /var/log/jira

# Configure Jira home
echo "jira.home=$JIRA_HOME" > $JIRA_INSTALL/atlassian-jira/WEB-INF/classes/jira-application.properties

# Disable automatic GC params script if it exists (it overrides our settings)
if [ -f "$JIRA_INSTALL/bin/set-gc-params.sh" ]; then
    echo "Disabling default set-gc-params.sh script..."
    mv $JIRA_INSTALL/bin/set-gc-params.sh $JIRA_INSTALL/bin/set-gc-params.sh.disabled
fi

# Database configuration file for setup wizard
cat > $JIRA_HOME/dbconfig.xml <<'DBCONFIG'
<?xml version="1.0" encoding="UTF-8"?>
<jira-database-config>
  <name>defaultDS</name>
  <delegator-name>default</delegator-name>
  <database-type>postgres72</database-type>
  <jdbc-datasource>
    <url>jdbc:postgresql://${db_endpoint}/${db_name}</url>
    <driver-class>org.postgresql.Driver</driver-class>
    <username>${db_username}</username>
    <password>${db_password}</password>
    <pool-min-size>20</pool-min-size>
    <pool-max-size>20</pool-max-size>
  </jdbc-datasource>
</jira-database-config>
DBCONFIG

# Ensure dbconfig.xml has correct permissions for Jira to update it
chmod 660 $JIRA_HOME/dbconfig.xml
chown jira:jira $JIRA_HOME/dbconfig.xml

# Backup existing setenv.sh if it exists
if [ -f "$JIRA_INSTALL/bin/setenv.sh" ]; then
    mv $JIRA_INSTALL/bin/setenv.sh $JIRA_INSTALL/bin/setenv.sh.backup
fi

# JVM configuration for t3.medium instance (4GB RAM)
cat > $JIRA_INSTALL/bin/setenv.sh <<'SETENV'
#!/bin/bash

# Set JIRA_HOME and log base directory
JIRA_HOME="/var/atlassian/application-data/jira"
LOGBASEABS="/var/atlassian/application-data/jira"

# JVM memory settings optimized for t3.medium (4GB RAM)
JVM_MINIMUM_MEMORY="1024m"
JVM_MAXIMUM_MEMORY="2048m"

# Java 17 optimizations
JVM_CODE_CACHE_ARGS="-XX:InitialCodeCacheSize=32m -XX:ReservedCodeCacheSize=512m"

# Build CATALINA_OPTS
CATALINA_OPTS="-Xms$${JVM_MINIMUM_MEMORY} -Xmx$${JVM_MAXIMUM_MEMORY} $${JVM_CODE_CACHE_ARGS}"

# Use G1GC garbage collector (recommended for Java 17)
CATALINA_OPTS="$${CATALINA_OPTS} -XX:+UseG1GC"
CATALINA_OPTS="$${CATALINA_OPTS} -XX:G1ReservePercent=20"
CATALINA_OPTS="$${CATALINA_OPTS} -XX:MaxGCPauseMillis=200"

# Additional Java 17 performance flags
CATALINA_OPTS="$${CATALINA_OPTS} -XX:+AlwaysPreTouch"
CATALINA_OPTS="$${CATALINA_OPTS} -XX:+UseStringDeduplication"

# GC logging configuration for Java 17 (using Unified Logging)
GC_JVM_PARAMETERS="-Xlog:gc*:file=$${LOGBASEABS}/logs/atlassian-jira-gc-%t.log:tags,time,uptime,level:filecount=5,filesize=20M"

# Export all settings
export JIRA_HOME
export LOGBASEABS
export GC_JVM_PARAMETERS
export CATALINA_OPTS="$${CATALINA_OPTS} $${GC_JVM_PARAMETERS}"
export JAVA_OPTS="$${JAVA_OPTS} -Djava.awt.headless=true"
SETENV

chmod +x $JIRA_INSTALL/bin/setenv.sh

# Systemd service
cat > /etc/systemd/system/jira.service <<'SERVICE'
[Unit]
Description=Atlassian Jira Software
After=network.target postgresql.service

[Service]
Type=forking
User=jira
Group=jira
Environment="JIRA_HOME=/var/atlassian/application-data/jira"
ExecStart=/opt/atlassian/jira/bin/start-jira.sh
ExecStop=/opt/atlassian/jira/bin/stop-jira.sh
ExecReload=/opt/atlassian/jira/bin/stop-jira.sh && /opt/atlassian/jira/bin/start-jira.sh
StandardOutput=journal
StandardError=journal
SyslogIdentifier=jira
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

# Wait for database to be ready
echo "Waiting for database to be available..."
until PGPASSWORD="${db_password}" psql -h "$(echo ${db_endpoint} | cut -d: -f1)" \
    -U "${db_username}" -d "${db_name}" -c '\q' 2>/dev/null; do
    echo "Database not ready yet, waiting..."
    sleep 5
done
echo "Database is ready!"

# Start Jira
systemctl daemon-reload
systemctl enable jira
systemctl start jira

# Wait for Jira to start
echo "Waiting for Jira to start..."
for i in {1..60}; do
    if curl -s -o /dev/null -w "%%{http_code}" http://localhost:8080/status | grep -q "200\|302"; then
        echo "Jira is running!"
        break
    fi
    echo "Waiting for Jira startup... ($$i/60)"
    sleep 10
done

echo "================================"
echo "Jira 10.3 LTS installation complete!"
echo "Database endpoint: ${db_endpoint}"
echo "Java version: $(java -version 2>&1 | head -n 1)"
echo ""
echo "Please access the setup wizard via the load balancer"
echo "Default port: 8080"
echo "================================"