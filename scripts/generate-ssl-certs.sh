#!/bin/bash
set -e

# Script to generate SSL certificates for Kafka
# This script generates a CA, server certificates, and client certificates
# for secure communication with Kafka

# Configuration
CERT_DIR="./ssl-certs"
PASSWORD="kafkasecret"
VALIDITY_DAYS=365
COUNTRY="US"
STATE="CA"
LOCALITY="San Francisco"
ORGANIZATION="DevOps Challenge"
ORGANIZATIONAL_UNIT="Engineering"
KAFKA_DOMAIN="*.kafka-service.kafka.svc.cluster.local"

# Create directory for certificates
mkdir -p $CERT_DIR

echo "=== Generating SSL certificates for Kafka ==="
echo "Certificates will be stored in $CERT_DIR"

# Generate CA key and certificate
echo "Generating CA key and certificate..."
openssl req -new -x509 -keyout $CERT_DIR/ca-key -out $CERT_DIR/ca-cert -days $VALIDITY_DAYS \
  -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORGANIZATIONAL_UNIT/CN=CA" \
  -passin pass:$PASSWORD -passout pass:$PASSWORD

# Generate server keystore
echo "Generating server keystore..."
keytool -keystore $CERT_DIR/kafka.server.keystore.jks -alias localhost -validity $VALIDITY_DAYS \
  -genkey -keyalg RSA \
  -dname "CN=$KAFKA_DOMAIN, OU=$ORGANIZATIONAL_UNIT, O=$ORGANIZATION, L=$LOCALITY, ST=$STATE, C=$COUNTRY" \
  -storepass $PASSWORD -keypass $PASSWORD

# Create server certificate signing request
echo "Creating server certificate signing request..."
keytool -keystore $CERT_DIR/kafka.server.keystore.jks -alias localhost \
  -certreq -file $CERT_DIR/kafka-server.csr \
  -storepass $PASSWORD -keypass $PASSWORD

# Sign the server certificate with CA
echo "Signing server certificate with CA..."
openssl x509 -req -CA $CERT_DIR/ca-cert -CAkey $CERT_DIR/ca-key -in $CERT_DIR/kafka-server.csr \
  -out $CERT_DIR/kafka-server-signed.crt -days $VALIDITY_DAYS \
  -CAcreateserial -passin pass:$PASSWORD

# Import CA certificate to server keystore
echo "Importing CA certificate to server keystore..."
keytool -keystore $CERT_DIR/kafka.server.keystore.jks -alias CARoot \
  -import -file $CERT_DIR/ca-cert \
  -storepass $PASSWORD -keypass $PASSWORD -noprompt

# Import signed server certificate to server keystore
echo "Importing signed server certificate to server keystore..."
keytool -keystore $CERT_DIR/kafka.server.keystore.jks -alias localhost \
  -import -file $CERT_DIR/kafka-server-signed.crt \
  -storepass $PASSWORD -keypass $PASSWORD -noprompt

# Create truststore and import CA certificate
echo "Creating truststore and importing CA certificate..."
keytool -keystore $CERT_DIR/kafka.client.truststore.jks -alias CARoot \
  -import -file $CERT_DIR/ca-cert \
  -storepass $PASSWORD -keypass $PASSWORD -noprompt

# Generate client keystore
echo "Generating client keystore..."
keytool -keystore $CERT_DIR/kafka.client.keystore.jks -alias localhost -validity $VALIDITY_DAYS \
  -genkey -keyalg RSA \
  -dname "CN=client, OU=$ORGANIZATIONAL_UNIT, O=$ORGANIZATION, L=$LOCALITY, ST=$STATE, C=$COUNTRY" \
  -storepass $PASSWORD -keypass $PASSWORD

# Create client certificate signing request
echo "Creating client certificate signing request..."
keytool -keystore $CERT_DIR/kafka.client.keystore.jks -alias localhost \
  -certreq -file $CERT_DIR/kafka-client.csr \
  -storepass $PASSWORD -keypass $PASSWORD

# Sign the client certificate with CA
echo "Signing client certificate with CA..."
openssl x509 -req -CA $CERT_DIR/ca-cert -CAkey $CERT_DIR/ca-key -in $CERT_DIR/kafka-client.csr \
  -out $CERT_DIR/kafka-client-signed.crt -days $VALIDITY_DAYS \
  -CAcreateserial -passin pass:$PASSWORD

# Import CA certificate to client keystore
echo "Importing CA certificate to client keystore..."
keytool -keystore $CERT_DIR/kafka.client.keystore.jks -alias CARoot \
  -import -file $CERT_DIR/ca-cert \
  -storepass $PASSWORD -keypass $PASSWORD -noprompt

# Import signed client certificate to client keystore
echo "Importing signed client certificate to client keystore..."
keytool -keystore $CERT_DIR/kafka.client.keystore.jks -alias localhost \
  -import -file $CERT_DIR/kafka-client-signed.crt \
  -storepass $PASSWORD -keypass $PASSWORD -noprompt

# Create properties files
echo "Creating SSL properties files..."

# Server properties
cat > $CERT_DIR/kafka-ssl-server.properties << EOF
security.protocol=SSL
ssl.keystore.location=/etc/kafka/ssl/kafka.server.keystore.jks
ssl.keystore.password=$PASSWORD
ssl.key.password=$PASSWORD
ssl.truststore.location=/etc/kafka/ssl/kafka.client.truststore.jks
ssl.truststore.password=$PASSWORD
ssl.client.auth=required
EOF

# Client properties
cat > $CERT_DIR/kafka-ssl-client.properties << EOF
security.protocol=SSL
ssl.keystore.location=/etc/kafka/ssl/kafka.client.keystore.jks
ssl.keystore.password=$PASSWORD
ssl.key.password=$PASSWORD
ssl.truststore.location=/etc/kafka/ssl/kafka.client.truststore.jks
ssl.truststore.password=$PASSWORD
EOF

# Create base64 encoded versions for Kubernetes secrets
echo "Creating base64 encoded files for Kubernetes secrets..."
BASE64_SERVER_KEYSTORE=$(base64 -w 0 $CERT_DIR/kafka.server.keystore.jks)
BASE64_CLIENT_TRUSTSTORE=$(base64 -w 0 $CERT_DIR/kafka.client.truststore.jks)
BASE64_CLIENT_KEYSTORE=$(base64 -w 0 $CERT_DIR/kafka.client.keystore.jks)
BASE64_SERVER_PROPERTIES=$(base64 -w 0 $CERT_DIR/kafka-ssl-server.properties)
BASE64_CLIENT_PROPERTIES=$(base64 -w 0 $CERT_DIR/kafka-ssl-client.properties)

# Create Kubernetes secret YAML
cat > $CERT_DIR/kafka-ssl-secrets.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: kafka-ssl-secrets
  namespace: kafka
type: Opaque
data:
  kafka.server.keystore.jks: $BASE64_SERVER_KEYSTORE
  kafka.client.truststore.jks: $BASE64_CLIENT_TRUSTSTORE
  kafka-ssl-server.properties: $BASE64_SERVER_PROPERTIES
EOF

cat > $CERT_DIR/kafka-ssl-client-secrets.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: kafka-ssl-client-secrets
  namespace: kafka
type: Opaque
data:
  kafka.client.keystore.jks: $BASE64_CLIENT_KEYSTORE
  kafka.client.truststore.jks: $BASE64_CLIENT_TRUSTSTORE
  kafka-ssl-client.properties: $BASE64_CLIENT_PROPERTIES
EOF

echo "=== SSL certificate generation complete ==="
echo "Files are available in $CERT_DIR"
echo "Use the following commands to create the Kubernetes secrets:"
echo "kubectl apply -f $CERT_DIR/kafka-ssl-secrets.yaml"
echo "kubectl apply -f $CERT_DIR/kafka-ssl-client-secrets.yaml"
