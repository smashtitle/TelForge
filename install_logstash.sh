#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e
# Print each command to stdout before executing it.
set -x

# Redirect all output to a log file for easier troubleshooting.
exec > >(tee /var/log/install-logstash.log) 2>&1

echo "Starting Logstash installation script..."

EVENTHUB_NAMESPACE="$1"
EVENTHUB_NAME="$2"
EVENTHUB_SAS_KEY_NAME="$3"
EVENTHUB_SAS_KEY="$4"

# --- 1. System Update and Prerequisites ---
# Non-interactive frontend to prevent prompts during apt-get install
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y wget gpg apt-transport-https default-jre

# Verify Java installation
java -version
echo "Java installation complete."

# --- 2. Add Elastic APT Repository ---
# Download and install the Elastic public signing key
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor --batch --yes -o /usr/share/keyrings/elastic-keyring.gpg

# Save the repository definition
echo "deb [signed-by=/usr/share/keyrings/elastic-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-9.x.list

echo "Elastic repository added."

# --- 3. Install Logstash ---
apt-get update -y
apt-get install -y logstash

echo "Logstash installation complete."

# --- 4. Fix Directory Permissions ---
# Set the correct ownership for the Logstash data directory to ensure writability.
echo "Setting ownership for Logstash data directory..."
chown -R logstash:logstash /var/lib/logstash

echo "Configuring Logstash service environment variables..."
mkdir -p /etc/systemd/system/logstash.service.d
cat <<EOF > /etc/systemd/system/logstash.service.d/override.conf
[Service]
Environment="EVENTHUB_NAMESPACE=${EVENTHUB_NAMESPACE}"
Environment="EVENTHUB_NAME=${EVENTHUB_NAME}"
Environment="EVENTHUB_SAS_KEY_NAME=${EVENTHUB_SAS_KEY_NAME}"
Environment="EVENTHUB_SAS_KEY=${EVENTHUB_SAS_KEY}"
EOF

# --- 5. Install Logstash Azure Event Hubs Plugin ---
# This plugin is required to send data to Azure Event Hubs
/usr/share/logstash/bin/logstash-plugin install logstash-output-azure_event_hubs
echo "Logstash Azure Event Hubs output plugin installed."

# --- 6. Deploy Logstash Configuration ---
# In a real-world scenario, you would pull these from a secure location (e.g., Azure Blob Storage with SAS token)
# For this example, we assume they are available alongside the script or are created dynamically.
# This section should be adapted to your configuration management strategy.
#
# wget -O /etc/logstash/conf.d/02-beats-input.conf <uri_to_input_config>
# wget -O /etc/logstash/conf.d/10-windows-filter.conf <uri_to_filter_config>
# wget -O /etc/logstash/conf.d/30-eventhub-output.conf <uri_to_output_config>

wget -O /etc/logstash/conf.d/logstash.conf https://github.com/smashtitle/TelForge/raw/refs/heads/main/logstash.conf

# --- 7. Enable and Start Logstash Service ---
# Ensure Logstash starts on boot and start it now
systemctl daemon-reload

systemctl enable logstash
systemctl start logstash
