#!/bin/bash
set -e

# Automated disaster recovery script for Kafka
# This script provides functions for backing up and restoring Kafka data

# Configuration
BACKUP_DIR="./kafka-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
NAMESPACE="kafka"
MIRROR_MAKER_CONFIG="k8s/kafka/mirror-maker/mm2.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if Kafka is running
check_kafka_status() {
    echo -e "${BLUE}Checking Kafka status...${RESET}"
    
    if ! kubectl get statefulset -n $NAMESPACE kafka &>/dev/null; then
        echo -e "${RED}Kafka StatefulSet not found in namespace $NAMESPACE${RESET}"
        return 1
    fi
    
    READY_REPLICAS=$(kubectl get statefulset -n $NAMESPACE kafka -o jsonpath='{.status.readyReplicas}')
    REPLICAS=$(kubectl get statefulset -n $NAMESPACE kafka -o jsonpath='{.status.replicas}')
    
    if [ "$READY_REPLICAS" != "$REPLICAS" ]; then
        echo -e "${YELLOW}Kafka is not fully ready. Ready: $READY_REPLICAS/$REPLICAS${RESET}"
        return 1
    fi
    
    echo -e "${GREEN}Kafka is running. Ready: $READY_REPLICAS/$REPLICAS${RESET}"
    return 0
}

# Function to backup Kafka topics metadata
backup_topics_metadata() {
    echo -e "${BLUE}Backing up Kafka topics metadata...${RESET}"
    
    # Get a list of all topics
    TOPICS_FILE="$BACKUP_DIR/topics-$TIMESTAMP.txt"
    
    kubectl exec -n $NAMESPACE kafka-0 -- kafka-topics --bootstrap-server localhost:9092 --list > $TOPICS_FILE
    
    echo -e "${GREEN}Topics list saved to $TOPICS_FILE${RESET}"
    
    # Get detailed information about each topic
    TOPICS_DETAILS_FILE="$BACKUP_DIR/topics-details-$TIMESTAMP.json"
    
    echo "[" > $TOPICS_DETAILS_FILE
    first=true
    
    while read -r topic; do
        if [ -z "$topic" ]; then
            continue
        fi
        
        if $first; then
            first=false
        else
            echo "," >> $TOPICS_DETAILS_FILE
        fi
        
        # Get topic details and format as JSON
        kubectl exec -n $NAMESPACE kafka-0 -- kafka-topics --bootstrap-server localhost:9092 --describe --topic "$topic" | \
        awk -v topic="$topic" 'BEGIN {
            print "  {";
            print "    \"topic\": \"" topic "\",";
        }
        /PartitionCount/ {
            split($0, parts, ",");
            for (i in parts) {
                if (parts[i] ~ /PartitionCount/) {
                    split(parts[i], pc, ":");
                    print "    \"partitionCount\": " pc[2] ",";
                }
                if (parts[i] ~ /ReplicationFactor/) {
                    split(parts[i], rf, ":");
                    print "    \"replicationFactor\": " rf[2] ",";
                }
            }
        }
        /Configs/ {
            gsub(/Configs:/, "");
            split($0, configs, ",");
            print "    \"configs\": {";
            for (i=1; i<=length(configs); i++) {
                if (configs[i] ~ /=/) {
                    split(configs[i], kv, "=");
                    gsub(/^[ \t]+|[ \t]+$/, "", kv[1]);
                    gsub(/^[ \t]+|[ \t]+$/, "", kv[2]);
                    print "      \"" kv[1] "\": \"" kv[2] "\"" (i<length(configs) ? "," : "");
                }
            }
            print "    }";
        }
        END {
            print "  }";
        }' >> $TOPICS_DETAILS_FILE
        
    done < $TOPICS_FILE
    
    echo "]" >> $TOPICS_DETAILS_FILE
    
    echo -e "${GREEN}Topics details saved to $TOPICS_DETAILS_FILE${RESET}"
}

# Function to backup consumer group offsets
backup_consumer_groups() {
    echo -e "${BLUE}Backing up consumer group offsets...${RESET}"
    
    # Get a list of all consumer groups
    GROUPS_FILE="$BACKUP_DIR/consumer-groups-$TIMESTAMP.txt"
    
    kubectl exec -n $NAMESPACE kafka-0 -- kafka-consumer-groups --bootstrap-server localhost:9092 --list > $GROUPS_FILE
    
    echo -e "${GREEN}Consumer groups list saved to $GROUPS_FILE${RESET}"
    
    # Get detailed information about each consumer group
    GROUPS_DETAILS_FILE="$BACKUP_DIR/consumer-groups-details-$TIMESTAMP.json"
    
    echo "[" > $GROUPS_DETAILS_FILE
    first=true
    
    while read -r group; do
        if [ -z "$group" ]; then
            continue
        fi
        
        if $first; then
            first=false
        else
            echo "," >> $GROUPS_DETAILS_FILE
        fi
        
        # Get consumer group details and format as JSON
        kubectl exec -n $NAMESPACE kafka-0 -- kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group "$group" | \
        awk -v group="$group" 'BEGIN {
            print "  {";
            print "    \"group\": \"" group "\",";
            print "    \"offsets\": [";
            first = 1;
        }
        NR > 1 && $1 != "TOPIC" && $1 != "" {
            if (first) {
                first = 0;
            } else {
                print ",";
            }
            print "      {";
            print "        \"topic\": \"" $1 "\",";
            print "        \"partition\": " $2 ",";
            print "        \"currentOffset\": " $3 ",";
            print "        \"logEndOffset\": " $4 ",";
            print "        \"lag\": " $5;
            print "      }";
        }
        END {
            print "    ]";
            print "  }";
        }' >> $GROUPS_DETAILS_FILE
        
    done < $GROUPS_FILE
    
    echo "]" >> $GROUPS_DETAILS_FILE
    
    echo -e "${GREEN}Consumer groups details saved to $GROUPS_DETAILS_FILE${RESET}"
}

# Function to backup ZooKeeper data
backup_zookeeper_data() {
    echo -e "${BLUE}Backing up ZooKeeper data...${RESET}"
    
    ZK_BACKUP_FILE="$BACKUP_DIR/zookeeper-backup-$TIMESTAMP.tar.gz"
    
    # Create a snapshot of ZooKeeper data
    kubectl exec -n $NAMESPACE zookeeper-0 -- bash -c "zkServer.sh stop && tar -czf /tmp/zk-backup.tar.gz /var/lib/zookeeper/data && zkServer.sh start"
    
    # Copy the snapshot to local machine
    kubectl cp $NAMESPACE/zookeeper-0:/tmp/zk-backup.tar.gz $ZK_BACKUP_FILE
    
    # Remove the snapshot from the pod
    kubectl exec -n $NAMESPACE zookeeper-0 -- rm /tmp/zk-backup.tar.gz
    
    echo -e "${GREEN}ZooKeeper data backed up to $ZK_BACKUP_FILE${RESET}"
}

# Function to setup Mirror Maker 2 for replication
setup_mirror_maker() {
    echo -e "${BLUE}Setting up Mirror Maker 2 for replication...${RESET}"
    
    if [ ! -f "$MIRROR_MAKER_CONFIG" ]; then
        echo -e "${RED}Mirror Maker configuration file not found: $MIRROR_MAKER_CONFIG${RESET}"
        return 1
    fi
    
    kubectl apply -f $MIRROR_MAKER_CONFIG
    
    echo -e "${GREEN}Mirror Maker 2 deployed for replication${RESET}"
}

# Function to restore topics
restore_topics() {
    echo -e "${BLUE}Restoring Kafka topics...${RESET}"
    
    # Check if backup files exist
    TOPICS_DETAILS_FILE=$1
    
    if [ ! -f "$TOPICS_DETAILS_FILE" ]; then
        echo -e "${RED}Topics details file not found: $TOPICS_DETAILS_FILE${RESET}"
        return 1
    fi
    
    # Parse JSON and recreate topics
    cat $TOPICS_DETAILS_FILE | jq -c '.[]' | while read -r topic_json; do
        TOPIC_NAME=$(echo $topic_json | jq -r '.topic')
        PARTITION_COUNT=$(echo $topic_json | jq -r '.partitionCount')
        REPLICATION_FACTOR=$(echo $topic_json | jq -r '.replicationFactor')
        
        echo -e "${YELLOW}Recreating topic: $TOPIC_NAME${RESET}"
        
        # Build the create topic command
        CREATE_CMD="kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic $TOPIC_NAME --partitions $PARTITION_COUNT --replication-factor $REPLICATION_FACTOR"
        
        # Add configs if any
        CONFIGS=$(echo $topic_json | jq -r '.configs | to_entries | map("--config " + .key + "=" + .value) | join(" ")')
        if [ ! -z "$CONFIGS" ]; then
            CREATE_CMD="$CREATE_CMD $CONFIGS"
        fi
        
        # Execute the command
        kubectl exec -n $NAMESPACE kafka-0 -- bash -c "$CREATE_CMD"
    done
    
    echo -e "${GREEN}Topics restored successfully${RESET}"
}

# Function to perform a full backup
full_backup() {
    echo -e "${BLUE}=== Starting full Kafka backup ===${RESET}"
    
    # Check if Kafka is running
    if ! check_kafka_status; then
        echo -e "${RED}Kafka is not running properly. Backup aborted.${RESET}"
        return 1
    fi
    
    # Create a backup directory for this run
    BACKUP_RUN_DIR="$BACKUP_DIR/backup-$TIMESTAMP"
    mkdir -p $BACKUP_RUN_DIR
    
    # Backup topics metadata
    backup_topics_metadata
    
    # Backup consumer group offsets
    backup_consumer_groups
    
    # Backup ZooKeeper data
    backup_zookeeper_data
    
    # Move all files to the backup run directory
    mv $BACKUP_DIR/*-$TIMESTAMP.* $BACKUP_RUN_DIR/
    
    echo -e "${GREEN}=== Full backup completed successfully ===${RESET}"
    echo -e "${GREEN}Backup files are available in $BACKUP_RUN_DIR${RESET}"
}

# Function to perform a disaster recovery
disaster_recovery() {
    echo -e "${BLUE}=== Starting Kafka disaster recovery ===${RESET}"
    
    # Check if backup directory exists
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED}Backup directory not found: $BACKUP_DIR${RESET}"
        return 1
    fi
    
    # List available backups
    echo -e "${YELLOW}Available backups:${RESET}"
    ls -1 $BACKUP_DIR | grep "^backup-" | nl
    
    # Ask user to select a backup
    echo -e "${YELLOW}Enter the number of the backup to restore:${RESET}"
    read backup_num
    
    SELECTED_BACKUP=$(ls -1 $BACKUP_DIR | grep "^backup-" | sed -n "${backup_num}p")
    
    if [ -z "$SELECTED_BACKUP" ]; then
        echo -e "${RED}Invalid backup selection${RESET}"
        return 1
    fi
    
    BACKUP_PATH="$BACKUP_DIR/$SELECTED_BACKUP"
    echo -e "${BLUE}Selected backup: $BACKUP_PATH${RESET}"
    
    # Check if Kafka is running
    if ! check_kafka_status; then
        echo -e "${YELLOW}Kafka is not running properly. Attempting to restart...${RESET}"
        
        # Restart Kafka
        kubectl rollout restart statefulset -n $NAMESPACE kafka
        
        # Wait for Kafka to be ready
        echo -e "${YELLOW}Waiting for Kafka to be ready...${RESET}"
        kubectl rollout status statefulset -n $NAMESPACE kafka --timeout=300s
        
        # Check again
        if ! check_kafka_status; then
            echo -e "${RED}Failed to restart Kafka. Recovery aborted.${RESET}"
            return 1
        fi
    fi
    
    # Restore topics
    TOPICS_DETAILS_FILE="$BACKUP_PATH/topics-details-*.json"
    TOPICS_DETAILS_FILE=$(ls $TOPICS_DETAILS_FILE 2>/dev/null || echo "")
    
    if [ ! -z "$TOPICS_DETAILS_FILE" ]; then
        restore_topics "$TOPICS_DETAILS_FILE"
    else
        echo -e "${YELLOW}No topics details file found in backup${RESET}"
    fi
    
    echo -e "${GREEN}=== Disaster recovery completed successfully ===${RESET}"
}

# Main function
main() {
    echo -e "${BLUE}=== Kafka Disaster Recovery Tool ===${RESET}"
    echo -e "${BLUE}1. Perform full backup${RESET}"
    echo -e "${BLUE}2. Perform disaster recovery${RESET}"
    echo -e "${BLUE}3. Setup Mirror Maker for replication${RESET}"
    echo -e "${BLUE}4. Exit${RESET}"
    
    echo -e "${YELLOW}Enter your choice:${RESET}"
    read choice
    
    case $choice in
        1)
            full_backup
            ;;
        2)
            disaster_recovery
            ;;
        3)
            setup_mirror_maker
            ;;
        4)
            echo -e "${GREEN}Exiting...${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${RESET}"
            ;;
    esac
}

# Check for required commands
for cmd in kubectl jq; do
    if ! command_exists $cmd; then
        echo -e "${RED}Error: $cmd is not installed. Please install it first.${RESET}"
        exit 1
    fi
done

# Run main function
main
