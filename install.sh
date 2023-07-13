###############
## Variables ##
###############

# This is the API key that you create in the GoDaddy Developer
APIKEY=ENTERGODADDYAPIKEY

# This is the API Secret that you create in the GoDaddy Developer
APISECRET=ENTERGODADDYAPISECRET

# Cert Email, this is the email that Let's Encrypt sends notifications
CERTMAIL=certadmin@email.com

# Domain, this is the URL name you are make the cert for
DOMAINNAME=*.mydomain.name

# Color Scheme Fun
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

##########################################################################
############## NO CHANGES FROM HERE DOWN SHOULD BE REQUIRED ##############
##########################################################################

# Update
echo -e "${green}# Updates${reset}"
dnf update -y

# Enable Extra Repo for CertBot
echo -e "${green}Enable Extra Repo for CertBot${reset}"
wget -O /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-8 https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-8
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-8
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm 
dnf install certbot python3-certbot-apache -y
echo -e "${green}Done${reset}"

# Create Directory and set permissions
mkdir -p /opt/scripts/
chown root:root /opt/scripts/
chmod 700 /opt/scripts/

# Create Script to create DNS TXT entry
echo -e "${green}Create Script to create DNS TXT entry${reset}"
cat << EOF >> /opt/scripts/api_create.sh
#!/bin/bash
set -e
set -u
set -o pipefail
export PATH="/usr/bin:/bin"
TMPFILE=\$(mktemp)

# Set your GoDaddy API key and secret
GODADDY_API_KEY="$APIKEY"
GODADDY_API_SECRET="$APISECRET"

# Extract the domain from the certbot parameters
DOMAIN=\$(expr match "\$CERTBOT_DOMAIN" '\\(.*\\)\\..*\\..*$')

# Create the DNS TXT record
curl -X PUT "https://api.godaddy.com/v1/domains/\$CERTBOT_DOMAIN/records/TXT/_acme-challenge.\$DOMAIN" \
-H "accept: application/json" \
-H "Content-Type: application/json" \
-H "Authorization: sso-key \$GODADDY_API_KEY:\$GODADDY_API_SECRET" \
-d "[{\\"data\\": \\"\$CERTBOT_VALIDATION\\", \\"ttl\\": 600}]"

# Wait for DNS propagation
echo "Waiting for DNS propagation..."
sleep 120

# Clean up the temporary file
rm -f \$TMPFILE
EOF

# Create Script to delete DNS TXT entry
echo -e "${green}Create Script to delete DNS TXT entry${reset}"
cat << EOF >> /opt/scripts/api_remove.sh
#!/bin/bash
set -e
set -u
set -o pipefail
export PATH="/usr/bin:/bin"

# Set your GoDaddy API key and secret
GODADDY_API_KEY="$APIKEY"
GODADDY_API_SECRET="$APISECRET"

# Extract the domain from the certbot parameters
DOMAIN=\$(expr match "\$CERTBOT_DOMAIN" '\\(.*\\)\\..*\\..*$')

# Remove the DNS TXT record
curl -X DELETE "https://api.godaddy.com/v1/domains/\$CERTBOT_DOMAIN/records/TXT/_acme-challenge.\$DOMAIN" \
-H "Authorization: sso-key \$GODADDY_API_KEY:\$GODADDY_API_SECRET"
EOF


# permissions for file
chown root:root /opt/scripts/api_create.sh /opt/scripts/api_remove.sh
chmod 700 /opt/scripts/api_create.sh /opt/scripts/api_remove.sh

# create a cron job
# Check if the cron job already exists
if crontab -l | grep -q "/usr/bin/certbot renew --quiet --post-hook \"systemctl reload httpd\""; then
    echo "Cron job already exists. Nothing to do."
else
    # Enter the cron job
    (crontab -l ; echo "30 2 * * * /usr/bin/certbot renew --quiet --post-hook \"systemctl reload httpd\"") | crontab -
    echo "Cron job added."
fi

clear

# Done
echo -e "${red}Information${reset}"
echo -e "${red}=====================${reset}"
echo ""
echo -e "${green}Create DNS Script Location${reset}"
echo -e "${green}/opt/scripts/api_create.sh${reset}"
echo ""
echo -e "${green}Remove DNS Script Location${reset}"
echo -e "${green}/opt/scripts/api_remove.sh${reset}"
echo ""
echo -e "${green}Cron Job${reset}"
echo -e "${green}30 2 * * * /usr/bin/certbot renew --quiet --post-hook "systemctl reload httpd"${reset}"
echo ""
echo -e "${green}Run the script for the first time${reset}"
echo ""
echo -e "${green}certbot certonly --manual --preferred-challenges=dns \
--manual-auth-hook /opt/scripts/auth_hook.sh \
--manual-cleanup-hook /opt/scripts/cleanup_hook.sh \
--non-interactive --agree-tos --email $CERTMAIL \
-d $DOMAINNAME ${reset}"




