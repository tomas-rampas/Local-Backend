# generate_certs.ps1

# Variables
$CaKeyPass = "changeme"      # Replace with a strong password
$CaCertPass = "changeme"     # Replace with a strong password
$CaCn = "artemisca"       # Replace with your CA name
$CertPass = "changeme"       # Replace with a strong password
$EsCn = "elasticsearch"      # Replace with your Elasticsearch hostname
$KiCn = "kibana"             # Replace with your Kibana hostname

# Generate CA private key
& openssl genrsa -aes256 -out ca.key -passout "pass:$CaKeyPass" 2048

# Generate CA certificate (valid for 10 years)
& openssl req -x509 -new -nodes -key ca.key -passin "pass:$CaKeyPass" -sha256 -days 3650 -out ca.crt -subj "/CN=$CaCn"

# Generate Elasticsearch private key
& openssl genrsa -out elasticsearch.key 2048

# Generate Elasticsearch CSR (Certificate Signing Request)
& openssl req -new -key elasticsearch.key -out elasticsearch.csr -subj "/CN=$EsCn" -config elasticsearch-cert.cnf

# Sign Elasticsearch certificate with the CA
# & openssl x509 -req -in elasticsearch.csr -CA ca.crt -CAkey ca.key -passin "pass:$CaKeyPass" -CAcreateserial -out elasticsearch.crt -days 365 -sha256
& openssl x509 -req -in elasticsearch.csr -CA ca.crt -CAkey ca.key -passin "pass:$CaKeyPass" -CAcreateserial -out elasticsearch.crt -days 365 -extensions v3_req -extfile elasticsearch-cert.cnf

# Generate Kibana private key
& openssl genrsa -out kibana.key 2048

# Generate Kibana CSR (Certificate Signing Request)
& openssl req -new -key kibana.key -out kibana.csr -subj "/CN=$KiCn"

# Sign Kibana certificate with the CA
& openssl x509 -req -in kibana.csr -CA ca.crt -CAkey ca.key -passin "pass:$CaKeyPass" -CAcreateserial -out kibana.crt -days 365 -sha256

# Convert Elasticsearch certificate and key to PKCS#12
& openssl pkcs12 -export -out elasticsearch.p12 -inkey elasticsearch.key -in elasticsearch.crt -passout "pass:$CertPass" -certfile ca.crt

# Convert Kibana certificate and key to PKCS#12
& openssl pkcs12 -export -out kibana.p12 -inkey kibana.key -in kibana.crt -passout "pass:$CertPass" -certfile ca.crt

# Add CA certificate to Elasticsearch PKCS#12 file
& openssl pkcs12 -export -in elasticsearch.crt -inkey elasticsearch.key -certfile ca.crt -out elasticsearch_with_ca.p12 -passout "pass:$CertPass"

Write-Host "Certificates generated successfully:"
Write-Host " - ca.crt (CA certificate)"
Write-Host " - elasticsearch.p12"
Write-Host " - elasticsearch_with_ca.p12 (includes CA)"
Write-Host " - kibana.p12"

# Install CA certificate to local machine's Trusted Root Certification Authorities
Write-Host ""
$installResult = & "$PSScriptRoot\Install-CACertificate.ps1" -CaCertPath "$(Get-Location)\ca.crt" -CaCn $CaCn

Write-Host ""
Write-Host "Certificate installation complete!"
Write-Host ""
Write-Host "Usage instructions:"
Write-Host "- Elasticsearch: https://localhost:9200 (user: elastic, password: $CertPass)"
Write-Host "- Kibana: http://localhost:5601"
Write-Host ""
Write-Host "To remove the CA certificate later, run:"
Write-Host "Get-ChildItem -Path 'Cert:\LocalMachine\Root' | Where-Object {`$_.Subject -like '*$CaCn*'} | Remove-Item"