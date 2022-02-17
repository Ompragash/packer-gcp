#!/bin/bash
#
# Install and Configure Code Server.

echo -n "Creating User: "
/sbin/useradd devops -p ansible
/sbin/usermod -aG wheel devops
echo "OK"

echo -n "Installing Required Packages: "
dnf install -y python38 git wget nano tree sshpass tmux gcc bind-utils emacs
echo "OK"

echo -n "Installing Code Server: "
dnf install -y https://github.com/coder/code-server/releases/download/v4.0.2/code-server-4.0.2-amd64.rpm
echo "OK"

echo -n "Configuring Code Server Unit File: "
cat << EOF >> /etc/systemd/system/code-server.service
[Unit]
Description=Code Server IDE
After=network.target

[Service]
Type=simple
User=devops
WorkingDirectory=/tmp/
Restart=on-failure
RestartSec=10

ExecStart=/bin/code-server --auth none
ExecStop=/bin/kill -s QUIT $MAINPID


[Install]
WantedBy=multi-user.target
EOF

/bin/chown devops:wheel /etc/systemd/system/code-server.service

/bin/chmod 0744 /etc/systemd/system/code-server.service

/bin/systemctl enable code-server
echo "OK"

echo -n "Setting Up Code Server For User 'devops': "
/bin/su devops -c "mkdir -p /home/devops/.local/share/code-server/User"

cat << EOF >> /home/devops/local/share/code-server/User/settings.json
{
    "git.ignoreLegacyWarning": true,
    "terminal.integrated.experimentalRefreshOnResume": true,
    "window.menuBarVisibility": "visible",
    "git.enableSmartCommit": true,
    "workbench.tips.enabled": false,
    "workbench.startupEditor": "readme",
    "telemetry.enableTelemetry": false,
    "search.smartCase": true,
    "git.confirmSync": false,
    "workbench.colorTheme": "Visual Studio Dark",
    "ansible.ansibleLint.enabled": false,
    "ansible.ansible.useFullyQualifiedCollectionNames": true
}
EOF
/bin/chown devops:wheel /home/devops/local/share/code-server/User/settings.json
echo "OK"

echo -n "Installing Required VisualStudio Code Plugins: "
# Create "extensions" directory
/bin/su devops -c "mkdir -v /home/devops/.local/share/code-server/extensions"
/bin/chown devops:devops /home/devops/.local/share/code-server/extensions

# Download required vscode plugins
/bin/su devops -c "wget https://github.com/ansible/workshops/raw/devel/files/bierner.markdown-preview-github-styles-0.1.6.vsix -P /tmp/"
/bin/su devops -c "wget https://github.com/ansible/workshops/raw/devel/files/hnw.vscode-auto-open-markdown-preview-0.0.4.vsix -P /tmp/"
/bin/su devops -c "wget https://github.com/ansible/workshops/raw/devel/files/redhat.ansible-0.4.5.vsix -P /tmp/"

# Installing vscode plugins
/bin/su devops -c "/bin/code-server --install-extension /tmp/bierner.markdown-preview-github-styles-0.1.6.vsix"
/bin/su devops -c "/bin/code-server --install-extension /tmp/hnw.vscode-auto-open-markdown-preview-0.0.4.vsix"
/bin/su devops -c "/bin/code-server --install-extension /tmp/redhat.ansible-0.4.5.vsix"

# Clean up the downloaded plugins
/bin/su devops -c "rm -rf /tmp/*.vsix"
echo "OK"

echo -n "Starting Code Server: "
systemctl daemon-reload
systemctl enable code-server
systemctl start code-server
echo "OK"

echo -n "Installing Nginx Web Server: "
dnf install -y Nginx
echo "OK"

# Update coder.json
sed -i 's/rhel/devops/g' /home/devops/.local/share/code-server/coder.json

echo -n "Adding Nginx Configuration to Support Code Server: "
cat << EOF >> /etc/nginx/default.d/custom.conf
# Custom configs for code-server
      location /editor/ {
          proxy_pass http://127.0.0.1:8080/;
          proxy_set_header Host $host;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection upgrade;
          proxy_set_header Accept-Encoding gzip;
          proxy_redirect off;
      }
EOF

setsebool -P httpd_can_network_connect on
echo "OK"

echo -n "Starting Nginx Server: "
systemctl enable nginx
systemctl start nginx
echo "OK"
