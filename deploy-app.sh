#!/bin/bash
# Bank Application Deployment Script for On-Premise VMs

set -e

# Configuration
APP_NAME="bankapp"
APP_USER="bankapp"
APP_GROUP="bankapp"
APP_HOME="/opt/bankapp"
APP_PORT=8080
MYSQL_HOST="localhost"  # Change to MySQL server IP if on different VM
MYSQL_PORT=3306
MYSQL_DB="bankappdb"
MYSQL_USER="bankappuser"
MYSQL_PASSWORD="BankApp@2024"

echo "=========================================="
echo "Bank Application Deployment Setup"
echo "=========================================="

# 1. Install Java 17 if not present
if ! command -v java &> /dev/null; then
    echo "Installing Java 17..."
    sudo apt update
    sudo apt install -y openjdk-17-jdk
else
    echo "Java is already installed: $(java -version 2>&1 | head -n 1)"
fi

# 2. Create application user
if ! id "$APP_USER" &>/dev/null; then
    echo "Creating application user..."
    sudo useradd -r -m -d "$APP_HOME" -s /bin/bash "$APP_USER"
fi

# 3. Create application directory
echo "Setting up application directory..."
sudo mkdir -p "$APP_HOME"
sudo chown -R "$APP_USER:$APP_GROUP" "$APP_HOME"

# 4. Build the application
echo "Building application with Maven..."
mvn clean package -DskipTests

# 5. Copy JAR to application directory
echo "Deploying application JAR..."
sudo cp target/*.jar "$APP_HOME/$APP_NAME.jar"
sudo chown "$APP_USER:$APP_GROUP" "$APP_HOME/$APP_NAME.jar"

# 6. Create systemd service file
echo "Creating systemd service..."
sudo tee /etc/systemd/system/${APP_NAME}.service > /dev/null <<EOF
[Unit]
Description=Bank Application
After=network.target mysql.service
Wants=mysql.service

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$APP_HOME
ExecStart=/usr/bin/java -jar $APP_HOME/$APP_NAME.jar \\
    --spring.datasource.url=jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true \\
    --spring.datasource.username=${MYSQL_USER} \\
    --spring.datasource.password=${MYSQL_PASSWORD} \\
    --server.port=${APP_PORT}
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bankapp

[Install]
WantedBy=multi-user.target
EOF

# 7. Reload systemd and enable service
echo "Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable ${APP_NAME}.service

# 8. Create log rotation
sudo tee /etc/logrotate.d/${APP_NAME} > /dev/null <<EOF
/var/log/${APP_NAME}/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    create 0640 ${APP_USER} ${APP_GROUP}
}
EOF

echo "=========================================="
echo "Deployment setup completed!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Update MySQL host in the systemd service if using remote MySQL:"
echo "   sudo nano /etc/systemd/system/${APP_NAME}.service"
echo ""
echo "2. Start the application:"
echo "   sudo systemctl start ${APP_NAME}"
echo ""
echo "3. Check application status:"
echo "   sudo systemctl status ${APP_NAME}"
echo ""
echo "4. View logs:"
echo "   sudo journalctl -u ${APP_NAME} -f"
echo ""
echo "5. Access application:"
echo "   http://localhost:${APP_PORT}/bankapp"
