#!/bin/bash
# generate-all-certificates.sh
# Master certificate generation script for Artemis Local Backend
# Generates CA and all service certificates in organized structure

set -e

# Default parameters
CA_NAME="${CA_NAME:-ArtemisLocalCA}"
CA_KEY_PASSWORD="${CA_KEY_PASSWORD:-changeme}"
CERT_PASSWORD="${CERT_PASSWORD:-changeme}"
CA_VALIDITY_DAYS="${CA_VALIDITY_DAYS:-3650}"
CERT_VALIDITY_DAYS="${CERT_VALIDITY_DAYS:-365}"
ORGANIZATION="${ORGANIZATION:-Artemis}"
ORGANIZATIONAL_UNIT="${ORGANIZATIONAL_UNIT:-Development}"
COUNTRY="${COUNTRY:-US}"
BACKUP_EXISTING="${BACKUP_EXISTING:-true}"
SKIP_IF_EXISTS="${SKIP_IF_EXISTS:-false}"

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$SCRIPT_DIR"

echo "=== Artemis Certificate Generation Script ==="
echo "Certificate directory: $CERTS_DIR"
echo ""

# Function to check if OpenSSL is available
check_openssl() {
    if ! command -v openssl &> /dev/null; then
        echo "ERROR: OpenSSL is required but not found in PATH."
        echo "Please install OpenSSL first."
        exit 1
    fi
}

# Function to check if keytool is available  
check_keytool() {
    if ! command -v keytool &> /dev/null; then
        echo "WARNING: keytool not found in PATH. Skipping JKS generation."
        echo "Install Java JDK to generate JKS keystores."
        return 1
    fi
    return 0
}

# Function to backup existing certificates
backup_existing_certs() {
    local backup_dir="$1"
    
    if [ -d "$backup_dir" ]; then
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        local backup_path="$CERTS_DIR/backup_$timestamp"
        echo "Backing up existing certificates to: $backup_path"
        
        cp -r "$backup_dir" "$backup_path"
        echo "✓ Backup completed"
    fi
}

# Function to generate CA certificate
generate_ca_certificate() {
    echo "Step 1: Generating Certificate Authority (CA)..."
    
    local ca_dir="$CERTS_DIR/ca"
    local ca_key_file="$ca_dir/ca.key"
    local ca_crt_file="$ca_dir/ca.crt"
    
    # Check if CA certificate file already exists
    if [ "$SKIP_IF_EXISTS" = "true" ] && [ -f "$ca_crt_file" ]; then
        echo "✓ CA certificate file already exists, skipping generation..."
        return
    fi
    
    if [ "$BACKUP_EXISTING" = "true" ]; then
        backup_existing_certs "$ca_dir"
    fi
    
    # Create CA directory
    mkdir -p "$ca_dir"
    
    # Generate CA private key
    echo "  Generating CA private key..."
    openssl genrsa -aes256 -out "$ca_key_file" -passout "pass:$CA_KEY_PASSWORD" 2048
    
    # Generate CA certificate
    echo "  Generating CA certificate..."
    local subject="/C=$COUNTRY/O=$ORGANIZATION/OU=$ORGANIZATIONAL_UNIT/CN=$CA_NAME"
    openssl req -x509 -new -nodes -key "$ca_key_file" -passin "pass:$CA_KEY_PASSWORD" \
        -sha256 -days "$CA_VALIDITY_DAYS" -out "$ca_crt_file" -subj "$subject"
    
    echo "✓ CA certificate generated successfully"
    echo "  CA Certificate: $ca_crt_file"
    echo "  CA Private Key: $ca_key_file"
}

# Function to generate service certificate
generate_service_certificate() {
    local service_name="$1"
    local alt_names="$2"
    local generate_jks="$3"
    local generate_p12="$4"
    
    echo "Step: Generating $service_name certificate..."
    
    local service_dir="$CERTS_DIR/${service_name,,}"  # Convert to lowercase
    local ca_dir="$CERTS_DIR/ca"
    local ca_key_file="$ca_dir/ca.key"
    local ca_crt_file="$ca_dir/ca.crt"
    
    # Service certificate files
    local service_key_file="$service_dir/$service_name.key"
    local service_csr_file="$service_dir/$service_name.csr" 
    local service_crt_file="$service_dir/$service_name.crt"
    local service_p12_file="$service_dir/$service_name.p12"
    local service_keystore_file="$service_dir/$service_name.keystore.jks"
    local service_truststore_file="$service_dir/$service_name.truststore.jks"
    
    if [ "$SKIP_IF_EXISTS" = "true" ] && [ -f "$service_crt_file" ]; then
        echo "✓ $service_name certificate already exists, skipping..."
        return
    fi
    
    if [ "$BACKUP_EXISTING" = "true" ]; then
        backup_existing_certs "$service_dir"
    fi
    
    # Create service directory
    mkdir -p "$service_dir"
    
    # Generate service private key
    echo "  Generating $service_name private key..."
    openssl genrsa -out "$service_key_file" 2048
    
    # Create certificate configuration with SAN
    local config_file="$service_dir/$service_name-cert.cnf"
    local san_list="$service_name,localhost,127.0.0.1"
    if [ -n "$alt_names" ]; then
        san_list="$san_list,$alt_names"
    fi
    
    # Convert comma-separated list to SAN format
    local san_dns=""
    local san_ip=""
    local dns_count=1
    local ip_count=1
    
    IFS=',' read -ra NAMES <<< "$san_list"
    for name in "${NAMES[@]}"; do
        name=$(echo "$name" | xargs)  # trim whitespace
        if [[ "$name" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            san_ip="${san_ip}IP.${ip_count} = ${name}\n"
            ((ip_count++))
        else
            san_dns="${san_dns}DNS.${dns_count} = ${name}\n"
            ((dns_count++))
        fi
    done
    
    cat > "$config_file" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = $COUNTRY
O = $ORGANIZATION
OU = $ORGANIZATIONAL_UNIT
CN = $service_name

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
$(printf "$san_dns$san_ip")
EOF
    
    # Generate certificate signing request
    echo "  Generating $service_name CSR..."
    openssl req -new -key "$service_key_file" -out "$service_csr_file" -config "$config_file"
    
    # Sign certificate with CA
    echo "  Signing $service_name certificate..."
    openssl x509 -req -in "$service_csr_file" -CA "$ca_crt_file" -CAkey "$ca_key_file" \
        -passin "pass:$CA_KEY_PASSWORD" -CAcreateserial -out "$service_crt_file" \
        -days "$CERT_VALIDITY_DAYS" -extensions v3_req -extfile "$config_file"
    
    # Generate PKCS#12 file if requested
    if [ "$generate_p12" = "true" ]; then
        echo "  Generating $service_name PKCS#12 file..."
        openssl pkcs12 -export -out "$service_p12_file" -inkey "$service_key_file" \
            -in "$service_crt_file" -certfile "$ca_crt_file" -passout "pass:$CERT_PASSWORD"
    fi
    
    # Generate JKS files if requested
    if [ "$generate_jks" = "true" ] && check_keytool; then
        echo "  Generating $service_name JKS keystore..."
        
        # Create keystore from PKCS#12
        keytool -importkeystore -srckeystore "$service_p12_file" -srcstoretype PKCS12 \
            -destkeystore "$service_keystore_file" -deststoretype JKS \
            -srcstorepass "$CERT_PASSWORD" -deststorepass "$CERT_PASSWORD" \
            -srcalias 1 -destalias "$service_name" -noprompt
        
        # Create truststore with CA certificate
        echo "  Generating $service_name JKS truststore..."
        keytool -import -trustcacerts -alias ca -file "$ca_crt_file" \
            -keystore "$service_truststore_file" -storepass "$CERT_PASSWORD" -noprompt
    fi
    
    echo "✓ $service_name certificate generated successfully"
    echo "  Certificate: $service_crt_file"
    echo "  Private Key: $service_key_file"
    if [ "$generate_p12" = "true" ]; then
        echo "  PKCS#12: $service_p12_file"
    fi
    if [ "$generate_jks" = "true" ] && check_keytool; then
        echo "  Keystore: $service_keystore_file"
        echo "  Truststore: $service_truststore_file"
    fi
    
    # Clean up temporary files
    rm -f "$config_file"
}

# Main execution
main() {
    # Check prerequisites
    check_openssl
    
    # Generate CA certificate
    generate_ca_certificate
    
    # Generate service certificates
    echo ""
    generate_service_certificate "elasticsearch" "artemis-elasticsearch,es,elastic" "true" "true"
    
    echo ""
    generate_service_certificate "kibana" "artemis-kibana,ki" "false" "true"
    
    echo ""
    generate_service_certificate "kafka" "artemis-kafka,broker" "true" "false"
    
    echo ""
    echo "=== Certificate Generation Complete ==="
    echo ""
    echo "Certificate Summary:"
    echo "- CA: $CA_NAME (valid for $CA_VALIDITY_DAYS days)"
    echo "- Service certificates valid for $CERT_VALIDITY_DAYS days"
    echo "- Certificate password: $CERT_PASSWORD"
    echo "- All certificates stored in: $CERTS_DIR"
    echo ""
    echo "✓ All certificates generated successfully!"
    echo ""
    echo "Note: To install the CA certificate in your browser/system:"
    echo "  - Import $CERTS_DIR/ca/ca.crt as a trusted root CA"
}

# Run main function
main "$@"