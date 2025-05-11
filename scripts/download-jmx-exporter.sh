#!/bin/bash
set -e

# Script to download JMX exporter JAR file

JMX_EXPORTER_VERSION="0.16.1"
JMX_EXPORTER_URL="https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"
OUTPUT_DIR="./local-dev/jmx-exporter"

# Create directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

echo "Downloading JMX exporter version ${JMX_EXPORTER_VERSION}..."
curl -L -o "${OUTPUT_DIR}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar" "${JMX_EXPORTER_URL}"
echo "Downloaded JMX exporter to ${OUTPUT_DIR}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"
