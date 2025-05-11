#!/usr/bin/env python3

import json
import argparse
import subprocess
import sys
from datetime import datetime

def colorize(text, color_code):
    """Add color to terminal output"""
    return f"\033[{color_code}m{text}\033[0m"

def run_kafka_consumer(topic, from_beginning, max_messages, namespace, pod_name):
    """Run kafka-console-consumer and capture the output"""
    from_beginning_flag = "--from-beginning" if from_beginning else ""
    max_messages_flag = f"--max-messages {max_messages}" if max_messages > 0 else ""
    
    cmd = f"kubectl exec -it -n {namespace} {pod_name} -- " \
          f"kafka-console-consumer --bootstrap-server localhost:9092 " \
          f"--topic {topic} {from_beginning_flag} {max_messages_flag}"
    
    print(f"Running command: {cmd}\n")
    
    process = subprocess.Popen(
        cmd,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    messages = []
    
    try:
        # Read messages
        for line in process.stdout:
            line = line.strip()
            if not line:
                continue
                
            messages.append(line)
            
            # Try to parse as JSON for pretty printing
            try:
                data = json.loads(line)
                print(colorize("Message:", "1;36"))  # Cyan
                print(json.dumps(data, indent=2))
                
                # If message has timestamp field, show it nicely formatted
                timestamp = None
                if 'timestamp' in data:
                    try:
                        timestamp = datetime.fromisoformat(data['timestamp'].replace('Z', '+00:00'))
                        print(colorize(f"Timestamp: {timestamp} (UTC)", "1;33"))  # Yellow
                    except:
                        pass
                
                print(colorize("----------------------------------------", "1;30"))  # Gray
            except json.JSONDecodeError:
                # If not valid JSON, just print the raw message
                print(colorize("Raw message:", "1;31"))  # Red
                print(line)
                print(colorize("----------------------------------------", "1;30"))  # Gray
                
    except KeyboardInterrupt:
        print(colorize("\nInterrupted by user", "1;33"))
    finally:
        process.terminate()
    
    return messages

def analyze_messages(messages):
    """Analyze the messages and display statistics"""
    if not messages:
        print(colorize("No messages found", "1;31"))
        return
    
    total = len(messages)
    json_count = 0
    non_json_count = 0
    ids = set()
    message_types = {}
    
    for msg in messages:
        try:
            data = json.loads(msg)
            json_count += 1
            
            # Collect statistics
            if 'id' in data:
                ids.add(data['id'])
            
            if 'message' in data:
                msg_type = data['message']
                message_types[msg_type] = message_types.get(msg_type, 0) + 1
                
        except json.JSONDecodeError:
            non_json_count += 1
    
    # Display statistics
    print(colorize("\n📊 Message Statistics:", "1;36"))
    print(f"  Total messages: {total}")
    print(f"  JSON messages: {json_count}")
    print(f"  Non-JSON messages: {non_json_count}")
    print(f"  Unique IDs: {len(ids)}")
    
    if message_types:
        print(colorize("\n📝 Message Types:", "1;36"))
        for msg_type, count in message_types.items():
            print(f"  {msg_type}: {count}")

def main():
    parser = argparse.ArgumentParser(description="Kafka Message Viewer and Analyzer")
    parser.add_argument("--topic", default="posts", help="Kafka topic to read from")
    parser.add_argument("--from-beginning", action="store_true", help="Read messages from the beginning")
    parser.add_argument("--max", type=int, default=0, help="Maximum number of messages to display (0 for unlimited)")
    parser.add_argument("--namespace", default="kafka", help="Kubernetes namespace where Kafka is running")
    parser.add_argument("--pod", default="kafka-0", help="Kafka pod name")
    parser.add_argument("--analyze-only", action="store_true", help="Only show statistics, not individual messages")
    
    args = parser.parse_args()
    
    print(colorize(f"Kafka Message Viewer and Analyzer", "1;37"))
    print(colorize(f"Topic: {args.topic}", "1;37"))
    print(colorize("Press Ctrl+C to stop viewing messages\n", "1;37"))
    
    messages = run_kafka_consumer(
        args.topic, 
        args.from_beginning, 
        args.max, 
        args.namespace, 
        args.pod
    )
    
    analyze_messages(messages)

if __name__ == "__main__":
    main()