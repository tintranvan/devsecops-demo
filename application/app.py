#!/usr/bin/env python3
import os
import json
import boto3
import threading
import time
from datetime import datetime
from flask import Flask, jsonify

app = Flask(__name__)

# SQS client
sqs = boto3.client('sqs')
queue_url = os.getenv('SQS_QUEUE_URL')

@app.route('/')
def home():
    return jsonify({
        "status": "healthy",
        "service": "demo-app",
        "timestamp": datetime.now().isoformat(),
        "environment": os.getenv("ENVIRONMENT", "dev"),
        "sqs_configured": bool(queue_url)
    })

@app.route('/health')
def health():
    return jsonify({
        "status": "healthy",
        "service": "demo-app"
    })

def sqs_listener():
    """Listen to SQS queue and print messages"""
    if not queue_url:
        print("SQS_QUEUE_URL not configured")
        return
    
    print(f"Starting SQS listener for queue: {queue_url}")
    
    while True:
        try:
            response = sqs.receive_message(
                QueueUrl=queue_url,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=20
            )
            
            messages = response.get('Messages', [])
            for message in messages:
                print(f"SQS Message received: {message['Body']}")
                
                # Delete message after processing
                sqs.delete_message(
                    QueueUrl=queue_url,
                    ReceiptHandle=message['ReceiptHandle']
                )
                print("Message processed and deleted")
                
        except Exception as e:
            print(f"SQS Error: {e}")
            time.sleep(5)

if __name__ == '__main__':
    # Start SQS listener in background thread
    if queue_url:
        sqs_thread = threading.Thread(target=sqs_listener, daemon=True)
        sqs_thread.start()
        print(f"SQS listener started for queue: {queue_url}")
    else:
        print("SQS_QUEUE_URL not configured, skipping SQS listener")
    
    app.run(host='0.0.0.0', port=8080, debug=False)
