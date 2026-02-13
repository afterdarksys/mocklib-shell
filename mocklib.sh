#!/bin/bash
# MockLib Shell Library - curl + jq wrapper for MockFactory API
#
# Usage:
#   export MOCKFACTORY_API_KEY="mf_..."
#   source mocklib.sh
#
#   mocklib_vpc_create "10.0.0.0/16"
#   mocklib_lambda_create "my-function" "python3.9" 256
#   mocklib_dynamodb_create_table "users" "user_id"

# Configuration
MOCKLIB_API_URL="${MOCKLIB_API_URL:-https://api.mockfactory.io/v1}"
MOCKLIB_API_KEY="${MOCKFACTORY_API_KEY}"

# Check dependencies
if ! command -v curl &> /dev/null; then
    echo "Error: curl is required but not installed" >&2
    return 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed" >&2
    echo "Install with: brew install jq" >&2
    return 1
fi

# Check API key
if [ -z "$MOCKLIB_API_KEY" ]; then
    echo "Error: MOCKFACTORY_API_KEY environment variable not set" >&2
    return 1
fi

# Helper: Make API request
mocklib_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"

    local url="${MOCKLIB_API_URL}${endpoint}"

    curl -s -X "${method}" \
        -H "Authorization: Bearer ${MOCKLIB_API_KEY}" \
        -H "Content-Type: application/json" \
        -H "User-Agent: mocklib-shell/0.1.0" \
        ${data:+-d "$data"} \
        "$url"
}

# ============================================================================
# VPC Operations
# ============================================================================

mocklib_vpc_create() {
    local cidr_block="$1"
    local enable_dns="${2:-true}"

    local data=$(cat <<EOF
{
  "Action": "CreateVpc",
  "CidrBlock": "$cidr_block",
  "EnableDnsHostnames": $enable_dns,
  "EnableDnsSupport": $enable_dns
}
EOF
)

    local response=$(mocklib_request "POST" "/aws/vpc" "$data")
    echo "$response" | jq -r '.VpcId'
}

mocklib_vpc_delete() {
    local vpc_id="$1"

    local data=$(cat <<EOF
{
  "Action": "DeleteVpc",
  "VpcId": "$vpc_id"
}
EOF
)

    mocklib_request "POST" "/aws/vpc" "$data"
}

mocklib_vpc_list() {
    local data='{"Action": "DescribeVpcs"}'
    local response=$(mocklib_request "POST" "/aws/vpc" "$data")
    echo "$response" | jq -r '.Vpcs[] | "\(.VpcId)\t\(.CidrBlock)\t\(.State)"'
}

# ============================================================================
# Lambda Operations
# ============================================================================

mocklib_lambda_create() {
    local function_name="$1"
    local runtime="$2"
    local memory_mb="${3:-128}"
    local timeout="${4:-30}"

    local data=$(cat <<EOF
{
  "Action": "CreateFunction",
  "FunctionName": "$function_name",
  "Runtime": "$runtime",
  "Handler": "index.handler",
  "MemorySize": $memory_mb,
  "Timeout": $timeout
}
EOF
)

    local response=$(mocklib_request "POST" "/aws/lambda" "$data")
    echo "$response" | jq -r '.FunctionId'
}

mocklib_lambda_invoke() {
    local function_name="$1"
    local payload="${2:-{}}"

    local data=$(cat <<EOF
{
  "Action": "Invoke",
  "FunctionName": "$function_name",
  "Payload": $payload
}
EOF
)

    local response=$(mocklib_request "POST" "/aws/lambda" "$data")
    echo "$response" | jq -r '.Payload'
}

mocklib_lambda_delete() {
    local function_name="$1"

    local data=$(cat <<EOF
{
  "Action": "DeleteFunction",
  "FunctionName": "$function_name"
}
EOF
)

    mocklib_request "POST" "/aws/lambda" "$data"
}

# ============================================================================
# DynamoDB Operations
# ============================================================================

mocklib_dynamodb_create_table() {
    local table_name="$1"
    local partition_key="$2"
    local partition_key_type="${3:-S}"

    local data=$(cat <<EOF
{
  "Action": "CreateTable",
  "TableName": "$table_name",
  "PartitionKey": "$partition_key",
  "PartitionKeyType": "$partition_key_type"
}
EOF
)

    local response=$(mocklib_request "POST" "/aws/dynamodb" "$data")
    echo "$response" | jq -r '.TableId'
}

mocklib_dynamodb_put_item() {
    local table_name="$1"
    local item="$2"

    local data=$(cat <<EOF
{
  "Action": "PutItem",
  "TableName": "$table_name",
  "Item": $item
}
EOF
)

    mocklib_request "POST" "/aws/dynamodb" "$data"
}

mocklib_dynamodb_get_item() {
    local table_name="$1"
    local key="$2"

    local data=$(cat <<EOF
{
  "Action": "GetItem",
  "TableName": "$table_name",
  "Key": $key
}
EOF
)

    local response=$(mocklib_request "POST" "/aws/dynamodb" "$data")
    echo "$response" | jq -r '.Item'
}

# ============================================================================
# SQS Operations
# ============================================================================

mocklib_sqs_create_queue() {
    local queue_name="$1"
    local visibility_timeout="${2:-30}"

    local data=$(cat <<EOF
{
  "Action": "CreateQueue",
  "QueueName": "$queue_name",
  "VisibilityTimeout": $visibility_timeout
}
EOF
)

    local response=$(mocklib_request "POST" "/aws/sqs" "$data")
    echo "$response" | jq -r '.QueueUrl'
}

mocklib_sqs_send_message() {
    local queue_url="$1"
    local message_body="$2"

    local data=$(cat <<EOF
{
  "Action": "SendMessage",
  "QueueUrl": "$queue_url",
  "MessageBody": "$message_body"
}
EOF
)

    local response=$(mocklib_request "POST" "/aws/sqs" "$data")
    echo "$response" | jq -r '.MessageId'
}

mocklib_sqs_receive_messages() {
    local queue_url="$1"
    local max_messages="${2:-1}"

    local data=$(cat <<EOF
{
  "Action": "ReceiveMessage",
  "QueueUrl": "$queue_url",
  "MaxNumberOfMessages": $max_messages
}
EOF
)

    local response=$(mocklib_request "POST" "/aws/sqs" "$data")
    echo "$response" | jq -r '.Messages[]'
}

# ============================================================================
# Helper functions
# ============================================================================

mocklib_version() {
    echo "mocklib-shell v0.1.0"
}

mocklib_help() {
    cat <<EOF
MockLib Shell Library - MockFactory API wrapper

Usage:
  source mocklib.sh
  mocklib_<resource>_<action> [args...]

VPC Commands:
  mocklib_vpc_create <cidr_block>                    Create VPC
  mocklib_vpc_delete <vpc_id>                        Delete VPC
  mocklib_vpc_list                                   List all VPCs

Lambda Commands:
  mocklib_lambda_create <name> <runtime> [memory]    Create Lambda function
  mocklib_lambda_invoke <name> [payload]             Invoke Lambda function
  mocklib_lambda_delete <name>                       Delete Lambda function

DynamoDB Commands:
  mocklib_dynamodb_create_table <name> <key>         Create DynamoDB table
  mocklib_dynamodb_put_item <table> <item_json>      Put item
  mocklib_dynamodb_get_item <table> <key_json>       Get item

SQS Commands:
  mocklib_sqs_create_queue <name>                    Create SQS queue
  mocklib_sqs_send_message <url> <message>           Send message
  mocklib_sqs_receive_messages <url> [max]           Receive messages

Examples:
  mocklib_vpc_create "10.0.0.0/16"
  mocklib_lambda_create "my-func" "python3.9" 256
  mocklib_dynamodb_create_table "users" "user_id"

Environment Variables:
  MOCKFACTORY_API_KEY    API key (required)
  MOCKLIB_API_URL        API base URL (default: https://api.mockfactory.io/v1)
EOF
}

echo "✓ MockLib Shell loaded (v0.1.0)"
echo "  Run 'mocklib_help' for usage"
