# generate_kafka_certs.ps1

# Variables
$KeystorePass = "changeme"
$TruststorePass = "changeme"
$KeyAlias = "kafka"
$CommonName = "kafka.example.com" # Replace with your Kafka hostname or IP

# Generate Keystore
& keytool -genkeypair `
        -alias $KeyAlias `
        -keyalg RSA `
        -keysize 2048 `
        -validity 365 `
        -keystore kafka.keystore.jks `
        -storepass $KeystorePass `
        -dname "CN=$CommonName, OU=Kafka, O=Example, L=City, S=State, C=US"

# Generate Truststore
& keytool -exportcert `
        -alias $KeyAlias `
        -keystore kafka.keystore.jks `
        -storepass $KeystorePass `
        -file kafka.cert

& keytool -importcert `
        -file kafka.cert `
        -alias $KeyAlias `
        -keystore kafka.truststore.jks `
        -storepass $TruststorePass `
        -noprompt

# Clean up temporary certificate
Remove-Item kafka.cert

Write-Host "Keystore (kafka.keystore.jks) and Truststore (kafka.truststore.jks) generated successfully."