# generate_certs.ps1

# Variables
$CaKeyPass = "changeme"      # Replace with a strong password
$CaCertPass = "changeme"   # Replace with a strong password
$CaCn = "ArtemisLocal"        # Replace with your CA name
$CertPass = "changeme"       # Replace with a strong password
$EsCn = "elasticsearch"         # Replace with your Elasticsearch hostname
$KiCn = "kibana"                  # Replace with your Kibana hostname

# Generate CA private key
& openssl genrsa -aes256 -out ca.key -passout "pass:$CaKeyPass" 2048

# Generate CA certificate (valid for 10 years)
& openssl req -x509 -new -nodes -key ca.key -passin "pass:$CaKeyPass" -sha256 -days 3650 -out ca.crt -subj "/CN=$CaCn"

# Generate Elasticsearch private key
& openssl genrsa -out elasticsearch.key 2048

# Generate Elasticsearch CSR (Certificate Signing Request)
& openssl req -new -key elasticsearch.key -out elasticsearch.csr -subj "/CN=$EsCn"

# Sign Elasticsearch certificate with the CA
& openssl x509 -req -in elasticsearch.csr -CA ca.crt -CAkey ca.key -CApassin "pass:$CaKeyPass" -CAcreateserial -out elasticsearch.crt -days 365

# Generate Kibana private key
& openssl genrsa -out kibana.key 2048

# Generate Kibana CSR (Certificate Signing Request)
& openssl req -new -key kibana.key -out kibana.csr -subj "/CN=$KiCn"

# Sign Kibana certificate with the CA
& openssl x509 -req -in kibana.csr -CA ca.crt -CAkey ca.key -CApassin "pass:$CaKeyPass" -CAcreateserial -out kibana.crt -days 365

# Convert Elasticsearch certificate and key to PKCS#12
& openssl pkcs12 -export -out elasticsearch.p12 -inkey elasticsearch.key -in elasticsearch.crt -passout "pass:$CertPass" -certfile ca.crt

# Convert Kibana certificate and key to PKCS#12
& openssl pkcs12 -export -out kibana.p12 -inkey kibana.key -in kibana.crt -passout "pass:$CertPass" -certfile ca.crt

Write-Host "Certificates generated successfully:"
Write-Host " - ca.crt (CA certificate)"
Write-Host " - elasticsearch.p12"
Write-Host " - kibana.p12"