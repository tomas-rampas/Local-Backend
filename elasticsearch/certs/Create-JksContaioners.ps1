& keytool -genkeypair -alias elasticsearch -keyalg RSA -keysize 2048 -validity 365 `
    -keystore elasticsearch.keystore.jks -storepass changeme `
    -dname "CN=elasticsearch, OU=CABTECH, O=Barclays, L=London, ST=London, C=UK"

& keytool -importkeystore `
    -srckeystore elasticsearch.p12 `
    -srcstoretype PKCS12 `
    -destkeystore elasticsearch.keystore.jks `
    -deststoretype JKS `
    -srcstorepass changeme `
    -deststorepass changeme    

& keytool -import -trustcacerts `
    -alias elasticsearch-ca `
    -file ca.crt `
    -keystore elasticsearch.truststore.jks `
    -storepass changeme `
    -noprompt


# & keytool -list -rfc -keystore elasticsearch.keystore.jks -storepass changeme | openssl x509 -text -noout