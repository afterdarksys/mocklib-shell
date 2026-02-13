#!/bin/bash
# MockLib Shell Demo
#
# Run:
#   export MOCKFACTORY_API_KEY="mf_..."
#   bash examples/demo.sh

set -e

# Load MockLib
source "$(dirname "$0")/../mocklib.sh"

echo "MockLib Shell Demo"
echo "==================\n"

# Create VPC
echo "→ Creating VPC..."
VPC_ID=$(mocklib_vpc_create "10.0.0.0/16")
echo "✓ Created VPC: $VPC_ID\n"

# Create Lambda function
echo "→ Creating Lambda function..."
LAMBDA_ID=$(mocklib_lambda_create "demo-function" "python3.9" 256)
echo "✓ Created Lambda: $LAMBDA_ID\n"

# Create DynamoDB table
echo "→ Creating DynamoDB table..."
TABLE_ID=$(mocklib_dynamodb_create_table "users" "user_id" "S")
echo "✓ Created table: $TABLE_ID\n"

# Create SQS queue
echo "→ Creating SQS queue..."
QUEUE_URL=$(mocklib_sqs_create_queue "background-jobs")
echo "✓ Created queue: $QUEUE_URL\n"

# Send SQS message
echo "→ Sending SQS message..."
MESSAGE_ID=$(mocklib_sqs_send_message "$QUEUE_URL" "Hello from MockLib Shell!")
echo "✓ Sent message: $MESSAGE_ID\n"

# List VPCs
echo "→ Listing all VPCs..."
mocklib_vpc_list
echo ""

echo "✅ Demo complete!"
echo "💰 Estimated cost: ~$0.05"
echo ""
echo "Clean up:"
echo "  mocklib_vpc_delete '$VPC_ID'"
echo "  mocklib_lambda_delete 'demo-function'"
