#!/bin/bash
# MockLib Shell Library - curl + jq wrapper for MockFactory API
#
# Usage:
#   export MOCKLIB_API_KEY="mf_..."   # or MOCKFACTORY_API_KEY
#   source mocklib.sh
#
#   mocklib_vpc_create "10.0.0.0/16"
#   mocklib_lambda_create "my-function" "python3.9" 256
#   mocklib_dynamodb_create_table "users" "user_id"

# ============================================================================
# Configuration
# ============================================================================

MOCKLIB_API_URL="${MOCKLIB_API_URL:-https://mockfactory.io/api/v1}"

# Accept either MOCKLIB_API_KEY or legacy MOCKFACTORY_API_KEY
if [ -n "$MOCKLIB_API_KEY" ]; then
    _MOCKLIB_KEY="$MOCKLIB_API_KEY"
elif [ -n "$MOCKFACTORY_API_KEY" ]; then
    _MOCKLIB_KEY="$MOCKFACTORY_API_KEY"
else
    _MOCKLIB_KEY=""
fi

# ============================================================================
# Dependency / config checks
# ============================================================================

if ! command -v curl &>/dev/null; then
    echo "Error: curl is required but not installed" >&2
    return 1 2>/dev/null || exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed" >&2
    echo "Install with: brew install jq" >&2
    return 1 2>/dev/null || exit 1
fi

if [ -z "$_MOCKLIB_KEY" ]; then
    echo "Error: MOCKLIB_API_KEY (or MOCKFACTORY_API_KEY) environment variable not set" >&2
    return 1 2>/dev/null || exit 1
fi

# ============================================================================
# Core request helpers
# ============================================================================

# mocklib_request METHOD ENDPOINT [JSON_BODY]
# Sends a JSON request (default Content-Type: application/json).
mocklib_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local url="${MOCKLIB_API_URL}${endpoint}"

    curl -s -X "${method}" \
        -H "X-API-Key: ${_MOCKLIB_KEY}" \
        -H "Content-Type: application/json" \
        -H "User-Agent: mocklib-shell/1.0.0" \
        ${data:+-d "$data"} \
        "$url"
}

# mocklib_request_form METHOD ENDPOINT FORM_BODY
# Sends an application/x-www-form-urlencoded request (AWS-style form posts).
mocklib_request_form() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local url="${MOCKLIB_API_URL}${endpoint}"

    curl -s -X "${method}" \
        -H "X-API-Key: ${_MOCKLIB_KEY}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "User-Agent: mocklib-shell/1.0.0" \
        ${data:+--data-urlencode "$data"} \
        "$url"
}

# mocklib_request_form_raw METHOD ENDPOINT RAW_FORM_STRING
# Like mocklib_request_form but passes the body verbatim (caller pre-encodes).
mocklib_request_form_raw() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local url="${MOCKLIB_API_URL}${endpoint}"

    curl -s -X "${method}" \
        -H "X-API-Key: ${_MOCKLIB_KEY}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "User-Agent: mocklib-shell/1.0.0" \
        ${data:+-d "$data"} \
        "$url"
}

# mocklib_request_target METHOD ENDPOINT JSON_BODY AMZTARGET
# For DynamoDB-style requests that need X-Amz-Target header.
mocklib_request_target() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local target="$4"
    local url="${MOCKLIB_API_URL}${endpoint}"

    curl -s -X "${method}" \
        -H "X-API-Key: ${_MOCKLIB_KEY}" \
        -H "Content-Type: application/json" \
        -H "X-Amz-Target: ${target}" \
        -H "User-Agent: mocklib-shell/1.0.0" \
        ${data:+-d "$data"} \
        "$url"
}

# ============================================================================
# STS Operations  (POST /sts/ — form body)
# ============================================================================

mocklib_sts_get_caller_identity() {
    local response
    response=$(mocklib_request_form_raw "POST" "/sts/" "Action=GetCallerIdentity")
    echo "$response"
}

mocklib_sts_assume_role() {
    local role_arn="$1"
    local session_name="$2"
    local response
    response=$(mocklib_request_form_raw "POST" "/sts/" \
        "Action=AssumeRole&RoleArn=${role_arn}&RoleSessionName=${session_name}")
    echo "$response"
}

mocklib_sts_get_session_token() {
    local response
    response=$(mocklib_request_form_raw "POST" "/sts/" "Action=GetSessionToken")
    echo "$response"
}

# ============================================================================
# EC2 Operations  (POST /ec2/ — form body)
# ============================================================================

mocklib_ec2_run_instances() {
    local instance_type="$1"
    local ami_id="$2"
    local count="${3:-1}"
    local response
    response=$(mocklib_request_form_raw "POST" "/ec2/" \
        "Action=RunInstances&InstanceType=${instance_type}&ImageId=${ami_id}&MinCount=${count}&MaxCount=${count}")
    echo "$response"
}

mocklib_ec2_describe_instances() {
    local response
    response=$(mocklib_request_form_raw "POST" "/ec2/" "Action=DescribeInstances")
    echo "$response"
}

mocklib_ec2_start_instances() {
    local instance_id="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/ec2/" \
        "Action=StartInstances&InstanceId.1=${instance_id}")
    echo "$response"
}

mocklib_ec2_stop_instances() {
    local instance_id="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/ec2/" \
        "Action=StopInstances&InstanceId.1=${instance_id}")
    echo "$response"
}

mocklib_ec2_terminate_instances() {
    local instance_id="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/ec2/" \
        "Action=TerminateInstances&InstanceId.1=${instance_id}")
    echo "$response"
}

mocklib_ec2_describe_images() {
    local response
    response=$(mocklib_request_form_raw "POST" "/ec2/" "Action=DescribeImages")
    echo "$response"
}

mocklib_ec2_describe_availability_zones() {
    local response
    response=$(mocklib_request_form_raw "POST" "/ec2/" "Action=DescribeAvailabilityZones")
    echo "$response"
}

# ============================================================================
# Route53 Operations  (POST /route53/ — form body)
# ============================================================================

mocklib_route53_create_zone() {
    local name="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/route53/" \
        "Action=CreateHostedZone&Name=${name}")
    echo "$response"
}

mocklib_route53_list_zones() {
    local response
    response=$(mocklib_request_form_raw "POST" "/route53/" "Action=ListHostedZones")
    echo "$response"
}

mocklib_route53_change_records() {
    local zone_id="$1"
    local action="$2"   # CREATE | UPSERT | DELETE
    local name="$3"
    local type="$4"
    local value="$5"
    local response
    response=$(mocklib_request_form_raw "POST" "/route53/" \
        "Action=ChangeResourceRecordSets&HostedZoneId=${zone_id}&ChangeBatch.Changes.1.Action=${action}&ChangeBatch.Changes.1.ResourceRecordSet.Name=${name}&ChangeBatch.Changes.1.ResourceRecordSet.Type=${type}&ChangeBatch.Changes.1.ResourceRecordSet.ResourceRecords.1.Value=${value}")
    echo "$response"
}

mocklib_route53_list_records() {
    local zone_id="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/route53/" \
        "Action=ListResourceRecordSets&HostedZoneId=${zone_id}")
    echo "$response"
}

# ============================================================================
# IAM Operations  (POST /iam/ — form body)
# ============================================================================

mocklib_iam_create_user() {
    local name="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/iam/" \
        "Action=CreateUser&UserName=${name}")
    echo "$response"
}

mocklib_iam_list_users() {
    local response
    response=$(mocklib_request_form_raw "POST" "/iam/" "Action=ListUsers")
    echo "$response"
}

mocklib_iam_get_user() {
    local name="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/iam/" \
        "Action=GetUser&UserName=${name}")
    echo "$response"
}

mocklib_iam_delete_user() {
    local name="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/iam/" \
        "Action=DeleteUser&UserName=${name}")
    echo "$response"
}

mocklib_iam_create_access_key() {
    local user="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/iam/" \
        "Action=CreateAccessKey&UserName=${user}")
    echo "$response"
}

mocklib_iam_list_access_keys() {
    local user="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/iam/" \
        "Action=ListAccessKeys&UserName=${user}")
    echo "$response"
}

mocklib_iam_create_role() {
    local name="$1"
    local policy="$2"   # JSON trust policy
    # URL-encode the policy inline via printf
    local encoded_policy
    encoded_policy=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$policy" 2>/dev/null \
        || jq -rn --arg p "$policy" '$p|@uri')
    local response
    response=$(mocklib_request_form_raw "POST" "/iam/" \
        "Action=CreateRole&RoleName=${name}&AssumeRolePolicyDocument=${encoded_policy}")
    echo "$response"
}

mocklib_iam_list_roles() {
    local response
    response=$(mocklib_request_form_raw "POST" "/iam/" "Action=ListRoles")
    echo "$response"
}

mocklib_iam_create_policy() {
    local name="$1"
    local document="$2"   # JSON policy document
    local encoded_doc
    encoded_doc=$(jq -rn --arg p "$document" '$p|@uri')
    local response
    response=$(mocklib_request_form_raw "POST" "/iam/" \
        "Action=CreatePolicy&PolicyName=${name}&PolicyDocument=${encoded_doc}")
    echo "$response"
}

mocklib_iam_attach_user_policy() {
    local user="$1"
    local policy_arn="$2"
    local response
    response=$(mocklib_request_form_raw "POST" "/iam/" \
        "Action=AttachUserPolicy&UserName=${user}&PolicyArn=${policy_arn}")
    echo "$response"
}

# ============================================================================
# Lambda Operations  (REST — /lambda/2015-03-31/functions[/{name}[/invocations]])
# ============================================================================

mocklib_lambda_create() {
    local function_name="$1"
    local runtime="$2"
    local memory_mb="${3:-128}"
    local timeout="${4:-30}"

    local data
    data=$(cat <<EOF
{
  "FunctionName": "$function_name",
  "Runtime": "$runtime",
  "Handler": "index.handler",
  "MemorySize": $memory_mb,
  "Timeout": $timeout
}
EOF
)
    local response
    response=$(mocklib_request "POST" "/lambda/2015-03-31/functions" "$data")
    echo "$response" | jq -r '.FunctionArn // .FunctionName // .'
}

mocklib_lambda_list() {
    local response
    response=$(mocklib_request "GET" "/lambda/2015-03-31/functions")
    echo "$response" | jq -r '.Functions[] | "\(.FunctionName)\t\(.Runtime)\t\(.FunctionArn)"'
}

mocklib_lambda_get() {
    local name="$1"
    local response
    response=$(mocklib_request "GET" "/lambda/2015-03-31/functions/${name}")
    echo "$response" | jq '.'
}

mocklib_lambda_invoke() {
    local function_name="$1"
    local payload="${2:-{}}"

    local response
    response=$(mocklib_request "POST" "/lambda/2015-03-31/functions/${function_name}/invocations" "$payload")
    echo "$response"
}

mocklib_lambda_delete() {
    local function_name="$1"
    mocklib_request "DELETE" "/lambda/2015-03-31/functions/${function_name}"
}

# ============================================================================
# SNS Operations  (POST /sns/ — form body)
# ============================================================================

mocklib_sns_create_topic() {
    local name="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/sns/" \
        "Action=CreateTopic&Name=${name}")
    echo "$response"
}

mocklib_sns_list_topics() {
    local response
    response=$(mocklib_request_form_raw "POST" "/sns/" "Action=ListTopics")
    echo "$response"
}

mocklib_sns_publish() {
    local topic_arn="$1"
    local message="$2"
    local response
    response=$(mocklib_request_form_raw "POST" "/sns/" \
        "Action=Publish&TopicArn=${topic_arn}&Message=${message}")
    echo "$response"
}

mocklib_sns_subscribe() {
    local topic_arn="$1"
    local protocol="$2"   # email | sqs | lambda | http | https
    local endpoint="$3"
    local response
    response=$(mocklib_request_form_raw "POST" "/sns/" \
        "Action=Subscribe&TopicArn=${topic_arn}&Protocol=${protocol}&Endpoint=${endpoint}")
    echo "$response"
}

# ============================================================================
# SQS Operations  (POST /aws/sqs — form body)
# ============================================================================

mocklib_sqs_create_queue() {
    local queue_name="$1"
    local visibility_timeout="${2:-30}"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/sqs" \
        "Action=CreateQueue&QueueName=${queue_name}&Attribute.1.Name=VisibilityTimeout&Attribute.1.Value=${visibility_timeout}")
    echo "$response" | jq -r '.QueueUrl // .'
}

mocklib_sqs_send_message() {
    local queue_url="$1"
    local message_body="$2"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/sqs" \
        "Action=SendMessage&QueueUrl=${queue_url}&MessageBody=${message_body}")
    echo "$response" | jq -r '.MessageId // .'
}

mocklib_sqs_receive_messages() {
    local queue_url="$1"
    local max_messages="${2:-1}"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/sqs" \
        "Action=ReceiveMessage&QueueUrl=${queue_url}&MaxNumberOfMessages=${max_messages}")
    echo "$response" | jq -r '.Messages[] // empty'
}

mocklib_sqs_delete_message() {
    local queue_url="$1"
    local receipt_handle="$2"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/sqs" \
        "Action=DeleteMessage&QueueUrl=${queue_url}&ReceiptHandle=${receipt_handle}")
    echo "$response"
}

mocklib_sqs_delete_queue() {
    local queue_url="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/sqs" \
        "Action=DeleteQueue&QueueUrl=${queue_url}")
    echo "$response"
}

mocklib_sqs_get_queue_attrs() {
    local queue_url="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/sqs" \
        "Action=GetQueueAttributes&QueueUrl=${queue_url}&AttributeName.1=All")
    echo "$response" | jq '.'
}

mocklib_sqs_purge_queue() {
    local queue_url="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/sqs" \
        "Action=PurgeQueue&QueueUrl=${queue_url}")
    echo "$response"
}

# ============================================================================
# DynamoDB Operations  (POST /aws/dynamodb — JSON + X-Amz-Target)
# ============================================================================

mocklib_dynamodb_create_table() {
    local table_name="$1"
    local partition_key="$2"
    local partition_key_type="${3:-S}"

    local data
    data=$(cat <<EOF
{
  "TableName": "$table_name",
  "KeySchema": [
    {"AttributeName": "$partition_key", "KeyType": "HASH"}
  ],
  "AttributeDefinitions": [
    {"AttributeName": "$partition_key", "AttributeType": "$partition_key_type"}
  ],
  "BillingMode": "PAY_PER_REQUEST"
}
EOF
)
    local response
    response=$(mocklib_request_target "POST" "/aws/dynamodb" "$data" "DynamoDB_20120810.CreateTable")
    echo "$response" | jq -r '.TableDescription.TableName // .TableId // .'
}

mocklib_dynamodb_put_item() {
    local table_name="$1"
    local item="$2"   # JSON map of DynamoDB-typed attributes

    local data
    data=$(cat <<EOF
{
  "TableName": "$table_name",
  "Item": $item
}
EOF
)
    mocklib_request_target "POST" "/aws/dynamodb" "$data" "DynamoDB_20120810.PutItem"
}

mocklib_dynamodb_get_item() {
    local table_name="$1"
    local key="$2"   # JSON map

    local data
    data=$(cat <<EOF
{
  "TableName": "$table_name",
  "Key": $key
}
EOF
)
    local response
    response=$(mocklib_request_target "POST" "/aws/dynamodb" "$data" "DynamoDB_20120810.GetItem")
    echo "$response" | jq -r '.Item // .'
}

mocklib_dynamodb_update_item() {
    local table="$1"
    local key="$2"       # JSON map
    local updates="$3"   # JSON map for UpdateExpression / ExpressionAttributeValues

    local data
    data=$(cat <<EOF
{
  "TableName": "$table",
  "Key": $key,
  "UpdateExpression": "SET #val = :val",
  "ExpressionAttributeValues": $updates
}
EOF
)
    mocklib_request_target "POST" "/aws/dynamodb" "$data" "DynamoDB_20120810.UpdateItem"
}

mocklib_dynamodb_delete_item() {
    local table="$1"
    local key="$2"   # JSON map

    local data
    data=$(cat <<EOF
{
  "TableName": "$table",
  "Key": $key
}
EOF
)
    mocklib_request_target "POST" "/aws/dynamodb" "$data" "DynamoDB_20120810.DeleteItem"
}

mocklib_dynamodb_query() {
    local table="$1"
    local condition="$2"   # KeyConditionExpression string

    local data
    data=$(cat <<EOF
{
  "TableName": "$table",
  "KeyConditionExpression": "$condition"
}
EOF
)
    local response
    response=$(mocklib_request_target "POST" "/aws/dynamodb" "$data" "DynamoDB_20120810.Query")
    echo "$response" | jq '.'
}

mocklib_dynamodb_scan() {
    local table="$1"

    local data
    data=$(cat <<EOF
{
  "TableName": "$table"
}
EOF
)
    local response
    response=$(mocklib_request_target "POST" "/aws/dynamodb" "$data" "DynamoDB_20120810.Scan")
    echo "$response" | jq -r '.Items[] // empty'
}

# ============================================================================
# VPC Operations  (POST /aws/vpc — form body)
# ============================================================================

mocklib_vpc_create() {
    local cidr_block="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/vpc" \
        "Action=CreateVpc&CidrBlock=${cidr_block}")
    echo "$response" | jq -r '.Vpc.VpcId // .VpcId // .'
}

mocklib_vpc_list() {
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/vpc" "Action=DescribeVpcs")
    echo "$response" | jq -r '.Vpcs[] | "\(.VpcId)\t\(.CidrBlock)\t\(.State)"'
}

mocklib_vpc_delete() {
    local vpc_id="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/vpc" \
        "Action=DeleteVpc&VpcId=${vpc_id}")
    echo "$response"
}

mocklib_vpc_create_subnet() {
    local vpc_id="$1"
    local cidr="$2"
    local az="$3"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/vpc" \
        "Action=CreateSubnet&VpcId=${vpc_id}&CidrBlock=${cidr}&AvailabilityZone=${az}")
    echo "$response" | jq -r '.Subnet.SubnetId // .SubnetId // .'
}

mocklib_vpc_describe_subnets() {
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/vpc" "Action=DescribeSubnets")
    echo "$response" | jq -r '.Subnets[] | "\(.SubnetId)\t\(.VpcId)\t\(.CidrBlock)\t\(.AvailabilityZone)"'
}

mocklib_vpc_delete_subnet() {
    local subnet_id="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/vpc" \
        "Action=DeleteSubnet&SubnetId=${subnet_id}")
    echo "$response"
}

mocklib_vpc_create_sg() {
    local vpc_id="$1"
    local name="$2"
    local desc="$3"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/vpc" \
        "Action=CreateSecurityGroup&VpcId=${vpc_id}&GroupName=${name}&Description=${desc}")
    echo "$response" | jq -r '.GroupId // .'
}

mocklib_vpc_describe_sgs() {
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/vpc" "Action=DescribeSecurityGroups")
    echo "$response" | jq -r '.SecurityGroups[] | "\(.GroupId)\t\(.GroupName)\t\(.VpcId)"'
}

mocklib_vpc_authorize_ingress() {
    local sg_id="$1"
    local protocol="$2"
    local from_port="$3"
    local to_port="$4"
    local cidr="$5"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/vpc" \
        "Action=AuthorizeSecurityGroupIngress&GroupId=${sg_id}&IpPermissions.1.IpProtocol=${protocol}&IpPermissions.1.FromPort=${from_port}&IpPermissions.1.ToPort=${to_port}&IpPermissions.1.IpRanges.1.CidrIp=${cidr}")
    echo "$response"
}

mocklib_vpc_create_igw() {
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/vpc" "Action=CreateInternetGateway")
    echo "$response" | jq -r '.InternetGateway.InternetGatewayId // .InternetGatewayId // .'
}

mocklib_vpc_attach_igw() {
    local igw_id="$1"
    local vpc_id="$2"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/vpc" \
        "Action=AttachInternetGateway&InternetGatewayId=${igw_id}&VpcId=${vpc_id}")
    echo "$response"
}

mocklib_vpc_create_rtb() {
    local vpc_id="$1"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/vpc" \
        "Action=CreateRouteTable&VpcId=${vpc_id}")
    echo "$response" | jq -r '.RouteTable.RouteTableId // .RouteTableId // .'
}

mocklib_vpc_create_route() {
    local rtb_id="$1"
    local cidr="$2"
    local gw_id="$3"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/vpc" \
        "Action=CreateRoute&RouteTableId=${rtb_id}&DestinationCidrBlock=${cidr}&GatewayId=${gw_id}")
    echo "$response"
}

mocklib_vpc_associate_rtb() {
    local rtb_id="$1"
    local subnet_id="$2"
    local response
    response=$(mocklib_request_form_raw "POST" "/aws/vpc" \
        "Action=AssociateRouteTable&RouteTableId=${rtb_id}&SubnetId=${subnet_id}")
    echo "$response" | jq -r '.AssociationId // .'
}

# ============================================================================
# OCI Object Storage  (/n/...)
# ============================================================================

mocklib_oci_get_namespace() {
    local response
    response=$(mocklib_request "GET" "/n")
    echo "$response" | jq -r '. // .'
}

mocklib_oci_list_buckets() {
    local namespace="${1:-mockfactory}"
    local response
    response=$(mocklib_request "GET" "/n/${namespace}/b")
    echo "$response" | jq -r '.[] | "\(.name)"'
}

mocklib_oci_create_bucket() {
    local namespace="${1:-mockfactory}"
    local name="$2"
    local data
    data=$(cat <<EOF
{"name": "$name"}
EOF
)
    local response
    response=$(mocklib_request "POST" "/n/${namespace}/b" "$data")
    echo "$response" | jq '.'
}

mocklib_oci_delete_bucket() {
    local namespace="${1:-mockfactory}"
    local bucket="$2"
    mocklib_request "DELETE" "/n/${namespace}/b/${bucket}"
}

mocklib_oci_put_object() {
    local namespace="${1:-mockfactory}"
    local bucket="$2"
    local object="$3"
    local file="$4"
    local url="${MOCKLIB_API_URL}/n/${namespace}/b/${bucket}/o/${object}"

    curl -s -X PUT \
        -H "X-API-Key: ${_MOCKLIB_KEY}" \
        -H "User-Agent: mocklib-shell/1.0.0" \
        --data-binary "@${file}" \
        "$url"
}

mocklib_oci_get_object() {
    local namespace="${1:-mockfactory}"
    local bucket="$2"
    local object="$3"
    local response
    response=$(mocklib_request "GET" "/n/${namespace}/b/${bucket}/o/${object}")
    echo "$response"
}

mocklib_oci_delete_object() {
    local namespace="${1:-mockfactory}"
    local bucket="$2"
    local object="$3"
    mocklib_request "DELETE" "/n/${namespace}/b/${bucket}/o/${object}"
}

# ============================================================================
# OCI Compute  (/20160918/...)
# ============================================================================

mocklib_oci_create_instance() {
    local shape="$1"
    local image_id="$2"
    local subnet_id="$3"
    local data
    data=$(cat <<EOF
{
  "shape": "$shape",
  "imageId": "$image_id",
  "subnetId": "$subnet_id"
}
EOF
)
    local response
    response=$(mocklib_request "POST" "/20160918/instances" "$data")
    echo "$response" | jq -r '.id // .'
}

mocklib_oci_list_instances() {
    local response
    response=$(mocklib_request "GET" "/20160918/instances")
    echo "$response" | jq -r '.[] | "\(.id)\t\(.displayName)\t\(.lifecycleState)"'
}

mocklib_oci_stop_instance() {
    local id="$1"
    local data='{"action":"stop"}'
    local response
    response=$(mocklib_request "POST" "/20160918/instances/${id}/actions/stop" "$data")
    echo "$response"
}

mocklib_oci_start_instance() {
    local id="$1"
    local data='{"action":"start"}'
    local response
    response=$(mocklib_request "POST" "/20160918/instances/${id}/actions/start" "$data")
    echo "$response"
}

mocklib_oci_delete_instance() {
    local id="$1"
    mocklib_request "DELETE" "/20160918/instances/${id}"
}

mocklib_oci_create_vcn() {
    local cidr="$1"
    local data
    data=$(cat <<EOF
{"cidrBlock": "$cidr"}
EOF
)
    local response
    response=$(mocklib_request "POST" "/20160918/vcns" "$data")
    echo "$response" | jq -r '.id // .'
}

mocklib_oci_list_vcns() {
    local response
    response=$(mocklib_request "GET" "/20160918/vcns")
    echo "$response" | jq -r '.[] | "\(.id)\t\(.cidrBlock)\t\(.lifecycleState)"'
}

mocklib_oci_create_volume() {
    local size_gb="$1"
    local data
    data=$(cat <<EOF
{"sizeInGBs": $size_gb}
EOF
)
    local response
    response=$(mocklib_request "POST" "/20160918/volumes" "$data")
    echo "$response" | jq -r '.id // .'
}

mocklib_oci_list_volumes() {
    local response
    response=$(mocklib_request "GET" "/20160918/volumes")
    echo "$response" | jq -r '.[] | "\(.id)\t\(.sizeInGBs)GB\t\(.lifecycleState)"'
}

# ============================================================================
# GCP Compute  (/gcp/compute/v1/...)
# ============================================================================

mocklib_gcp_list_zones() {
    local project="$1"
    local response
    response=$(mocklib_request "GET" "/gcp/compute/v1/projects/${project}/zones")
    echo "$response" | jq -r '.items[] | "\(.name)\t\(.status)"'
}

mocklib_gcp_create_instance() {
    local project="$1"
    local zone="$2"
    local name="$3"
    local machine_type="${4:-n1-standard-1}"
    local data
    data=$(cat <<EOF
{
  "name": "$name",
  "machineType": "zones/$zone/machineTypes/$machine_type"
}
EOF
)
    local response
    response=$(mocklib_request "POST" "/gcp/compute/v1/projects/${project}/zones/${zone}/instances" "$data")
    echo "$response" | jq -r '.name // .id // .'
}

mocklib_gcp_list_instances() {
    local project="$1"
    local zone="$2"
    local response
    response=$(mocklib_request "GET" "/gcp/compute/v1/projects/${project}/zones/${zone}/instances")
    echo "$response" | jq -r '.items[] | "\(.name)\t\(.status)\t\(.machineType)"'
}

mocklib_gcp_delete_instance() {
    local project="$1"
    local zone="$2"
    local name="$3"
    mocklib_request "DELETE" "/gcp/compute/v1/projects/${project}/zones/${zone}/instances/${name}"
}

mocklib_gcp_start_instance() {
    local project="$1"
    local zone="$2"
    local name="$3"
    local response
    response=$(mocklib_request "POST" "/gcp/compute/v1/projects/${project}/zones/${zone}/instances/${name}/start")
    echo "$response"
}

mocklib_gcp_stop_instance() {
    local project="$1"
    local zone="$2"
    local name="$3"
    local response
    response=$(mocklib_request "POST" "/gcp/compute/v1/projects/${project}/zones/${zone}/instances/${name}/stop")
    echo "$response"
}

mocklib_gcp_create_network() {
    local project="$1"
    local name="$2"
    local data
    data=$(cat <<EOF
{"name": "$name", "autoCreateSubnetworks": true}
EOF
)
    local response
    response=$(mocklib_request "POST" "/gcp/compute/v1/projects/${project}/global/networks" "$data")
    echo "$response" | jq -r '.name // .id // .'
}

mocklib_gcp_list_networks() {
    local project="$1"
    local response
    response=$(mocklib_request "GET" "/gcp/compute/v1/projects/${project}/global/networks")
    echo "$response" | jq -r '.items[] | "\(.name)\t\(.autoCreateSubnetworks)"'
}

mocklib_gcp_create_firewall() {
    local project="$1"
    local name="$2"
    local network="$3"
    local protocol="$4"
    local ports="$5"   # e.g. "80,443" or "22"
    local data
    data=$(cat <<EOF
{
  "name": "$name",
  "network": "global/networks/$network",
  "allowed": [{"IPProtocol": "$protocol", "ports": ["$ports"]}]
}
EOF
)
    local response
    response=$(mocklib_request "POST" "/gcp/compute/v1/projects/${project}/global/firewalls" "$data")
    echo "$response" | jq -r '.name // .id // .'
}

mocklib_gcp_list_firewalls() {
    local project="$1"
    local response
    response=$(mocklib_request "GET" "/gcp/compute/v1/projects/${project}/global/firewalls")
    echo "$response" | jq -r '.items[] | "\(.name)\t\(.network)"'
}

# ============================================================================
# Azure  (/azure/subscriptions/{sub}/...)
# ============================================================================

mocklib_azure_list_resource_groups() {
    local sub="$1"
    local response
    response=$(mocklib_request "GET" "/azure/subscriptions/${sub}/resourceGroups")
    echo "$response" | jq -r '.value[] | "\(.name)\t\(.location)\t\(.properties.provisioningState)"'
}

mocklib_azure_create_resource_group() {
    local sub="$1"
    local name="$2"
    local location="$3"
    local data
    data=$(cat <<EOF
{"location": "$location"}
EOF
)
    local response
    response=$(mocklib_request "PUT" "/azure/subscriptions/${sub}/resourceGroups/${name}" "$data")
    echo "$response" | jq -r '.name // .'
}

mocklib_azure_create_vnet() {
    local sub="$1"
    local rg="$2"
    local name="$3"
    local address_space="$4"   # e.g. "10.0.0.0/16"
    local data
    data=$(cat <<EOF
{
  "location": "eastus",
  "properties": {
    "addressSpace": {"addressPrefixes": ["$address_space"]}
  }
}
EOF
)
    local response
    response=$(mocklib_request "PUT" \
        "/azure/subscriptions/${sub}/resourceGroups/${rg}/providers/Microsoft.Network/virtualNetworks/${name}" \
        "$data")
    echo "$response" | jq -r '.name // .'
}

mocklib_azure_list_vnets() {
    local sub="$1"
    local rg="$2"
    local response
    response=$(mocklib_request "GET" \
        "/azure/subscriptions/${sub}/resourceGroups/${rg}/providers/Microsoft.Network/virtualNetworks")
    echo "$response" | jq -r '.value[] | "\(.name)\t\(.location)"'
}

mocklib_azure_delete_vnet() {
    local sub="$1"
    local rg="$2"
    local name="$3"
    mocklib_request "DELETE" \
        "/azure/subscriptions/${sub}/resourceGroups/${rg}/providers/Microsoft.Network/virtualNetworks/${name}"
}

mocklib_azure_create_nsg() {
    local sub="$1"
    local rg="$2"
    local name="$3"
    local data
    data=$(cat <<EOF
{"location": "eastus", "properties": {}}
EOF
)
    local response
    response=$(mocklib_request "PUT" \
        "/azure/subscriptions/${sub}/resourceGroups/${rg}/providers/Microsoft.Network/networkSecurityGroups/${name}" \
        "$data")
    echo "$response" | jq -r '.name // .'
}

mocklib_azure_create_vm() {
    local sub="$1"
    local rg="$2"
    local name="$3"
    local size="${4:-Standard_D2s_v3}"
    local image="${5:-UbuntuServer}"
    local data
    data=$(cat <<EOF
{
  "location": "eastus",
  "properties": {
    "hardwareProfile": {"vmSize": "$size"},
    "storageProfile": {"imageReference": {"offer": "$image"}}
  }
}
EOF
)
    local response
    response=$(mocklib_request "PUT" \
        "/azure/subscriptions/${sub}/resourceGroups/${rg}/providers/Microsoft.Compute/virtualMachines/${name}" \
        "$data")
    echo "$response" | jq -r '.name // .'
}

mocklib_azure_list_vms() {
    local sub="$1"
    local rg="$2"
    local response
    response=$(mocklib_request "GET" \
        "/azure/subscriptions/${sub}/resourceGroups/${rg}/providers/Microsoft.Compute/virtualMachines")
    echo "$response" | jq -r '.value[] | "\(.name)\t\(.location)\t\(.properties.provisioningState)"'
}

mocklib_azure_get_vm() {
    local sub="$1"
    local rg="$2"
    local name="$3"
    local response
    response=$(mocklib_request "GET" \
        "/azure/subscriptions/${sub}/resourceGroups/${rg}/providers/Microsoft.Compute/virtualMachines/${name}")
    echo "$response" | jq '.'
}

mocklib_azure_delete_vm() {
    local sub="$1"
    local rg="$2"
    local name="$3"
    mocklib_request "DELETE" \
        "/azure/subscriptions/${sub}/resourceGroups/${rg}/providers/Microsoft.Compute/virtualMachines/${name}"
}

mocklib_azure_start_vm() {
    local sub="$1"
    local rg="$2"
    local name="$3"
    local response
    response=$(mocklib_request "POST" \
        "/azure/subscriptions/${sub}/resourceGroups/${rg}/providers/Microsoft.Compute/virtualMachines/${name}/start")
    echo "$response"
}

mocklib_azure_stop_vm() {
    local sub="$1"
    local rg="$2"
    local name="$3"
    local response
    response=$(mocklib_request "POST" \
        "/azure/subscriptions/${sub}/resourceGroups/${rg}/providers/Microsoft.Compute/virtualMachines/${name}/powerOff")
    echo "$response"
}

mocklib_azure_deallocate_vm() {
    local sub="$1"
    local rg="$2"
    local name="$3"
    local response
    response=$(mocklib_request "POST" \
        "/azure/subscriptions/${sub}/resourceGroups/${rg}/providers/Microsoft.Compute/virtualMachines/${name}/deallocate")
    echo "$response"
}

mocklib_azure_restart_vm() {
    local sub="$1"
    local rg="$2"
    local name="$3"
    local response
    response=$(mocklib_request "POST" \
        "/azure/subscriptions/${sub}/resourceGroups/${rg}/providers/Microsoft.Compute/virtualMachines/${name}/restart")
    echo "$response"
}

# ============================================================================
# Legacy / generic storage helpers (kept for backwards compatibility)
# ============================================================================

mocklib_storage_create_bucket() {
    local bucket_name="$1"
    local provider="${2:-s3}"
    local region="${3:-us-east-1}"

    local data
    data=$(cat <<EOF
{
  "Action": "CreateBucket",
  "BucketName": "$bucket_name",
  "Provider": "$provider",
  "Region": "$region"
}
EOF
)
    local response
    response=$(mocklib_request "POST" "/storage/bucket" "$data")
    echo "$response" | jq -r '.BucketId // .'
}

mocklib_storage_upload_object() {
    local bucket_name="$1"
    local key="$2"
    local data_val="$3"

    local data
    data=$(cat <<EOF
{
  "Action": "PutObject",
  "BucketName": "$bucket_name",
  "Key": "$key",
  "Data": "$data_val"
}
EOF
)
    mocklib_request "POST" "/storage/object" "$data"
}

mocklib_storage_delete_bucket() {
    local bucket_name="$1"

    local data
    data=$(cat <<EOF
{
  "Action": "DeleteBucket",
  "BucketName": "$bucket_name"
}
EOF
)
    mocklib_request "POST" "/storage/bucket" "$data"
}

# ============================================================================
# Utility
# ============================================================================

mocklib_version() {
    echo "mocklib-shell v1.0.0"
}

mocklib_help() {
    cat <<'EOF'
MockLib Shell Library v1.0.0 — MockFactory API wrapper
Pure bash + curl + jq, no other dependencies.

Usage:
  export MOCKLIB_API_KEY="mf_..."   # or MOCKFACTORY_API_KEY
  source mocklib.sh
  mocklib_<service>_<action> [args...]

Environment Variables:
  MOCKLIB_API_KEY        API key (preferred)
  MOCKFACTORY_API_KEY    API key (legacy alias)
  MOCKLIB_API_URL        Base URL (default: https://mockfactory.io/api/v1)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STS  (POST /sts/)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mocklib_sts_get_caller_identity
  mocklib_sts_assume_role <role_arn> <session_name>
  mocklib_sts_get_session_token

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EC2  (POST /ec2/)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mocklib_ec2_run_instances <instance_type> <ami_id> [count]
  mocklib_ec2_describe_instances
  mocklib_ec2_start_instances <instance_id>
  mocklib_ec2_stop_instances <instance_id>
  mocklib_ec2_terminate_instances <instance_id>
  mocklib_ec2_describe_images
  mocklib_ec2_describe_availability_zones

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Route53  (POST /route53/)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mocklib_route53_create_zone <name>
  mocklib_route53_list_zones
  mocklib_route53_change_records <zone_id> <action> <name> <type> <value>
  mocklib_route53_list_records <zone_id>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
IAM  (POST /iam/)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mocklib_iam_create_user <name>
  mocklib_iam_list_users
  mocklib_iam_get_user <name>
  mocklib_iam_delete_user <name>
  mocklib_iam_create_access_key <username>
  mocklib_iam_list_access_keys <username>
  mocklib_iam_create_role <name> <trust_policy_json>
  mocklib_iam_list_roles
  mocklib_iam_create_policy <name> <policy_document_json>
  mocklib_iam_attach_user_policy <username> <policy_arn>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Lambda  (REST /lambda/2015-03-31/functions[/{name}])
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mocklib_lambda_create <name> <runtime> [memory_mb] [timeout]
  mocklib_lambda_list
  mocklib_lambda_get <name>
  mocklib_lambda_invoke <name> [payload_json]
  mocklib_lambda_delete <name>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SNS  (POST /sns/)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mocklib_sns_create_topic <name>
  mocklib_sns_list_topics
  mocklib_sns_publish <topic_arn> <message>
  mocklib_sns_subscribe <topic_arn> <protocol> <endpoint>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SQS  (POST /aws/sqs)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mocklib_sqs_create_queue <name> [visibility_timeout]
  mocklib_sqs_send_message <queue_url> <message>
  mocklib_sqs_receive_messages <queue_url> [max]
  mocklib_sqs_delete_message <queue_url> <receipt_handle>
  mocklib_sqs_delete_queue <queue_url>
  mocklib_sqs_get_queue_attrs <queue_url>
  mocklib_sqs_purge_queue <queue_url>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DynamoDB  (POST /aws/dynamodb — X-Amz-Target header)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mocklib_dynamodb_create_table <name> <partition_key> [key_type]
  mocklib_dynamodb_put_item <table> <item_json>
  mocklib_dynamodb_get_item <table> <key_json>
  mocklib_dynamodb_update_item <table> <key_json> <expression_values_json>
  mocklib_dynamodb_delete_item <table> <key_json>
  mocklib_dynamodb_query <table> <key_condition_expression>
  mocklib_dynamodb_scan <table>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
VPC  (POST /aws/vpc)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mocklib_vpc_create <cidr_block>
  mocklib_vpc_list
  mocklib_vpc_delete <vpc_id>
  mocklib_vpc_create_subnet <vpc_id> <cidr> <az>
  mocklib_vpc_describe_subnets
  mocklib_vpc_delete_subnet <subnet_id>
  mocklib_vpc_create_sg <vpc_id> <name> <description>
  mocklib_vpc_describe_sgs
  mocklib_vpc_authorize_ingress <sg_id> <protocol> <from_port> <to_port> <cidr>
  mocklib_vpc_create_igw
  mocklib_vpc_attach_igw <igw_id> <vpc_id>
  mocklib_vpc_create_rtb <vpc_id>
  mocklib_vpc_create_route <rtb_id> <cidr> <gw_id>
  mocklib_vpc_associate_rtb <rtb_id> <subnet_id>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OCI Object Storage  (/n/{ns}/...)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mocklib_oci_get_namespace
  mocklib_oci_list_buckets [namespace]
  mocklib_oci_create_bucket [namespace] <name>
  mocklib_oci_delete_bucket [namespace] <bucket>
  mocklib_oci_put_object [namespace] <bucket> <object> <local_file>
  mocklib_oci_get_object [namespace] <bucket> <object>
  mocklib_oci_delete_object [namespace] <bucket> <object>

OCI Compute  (/20160918/...)
  mocklib_oci_create_instance <shape> <image_id> <subnet_id>
  mocklib_oci_list_instances
  mocklib_oci_stop_instance <id>
  mocklib_oci_start_instance <id>
  mocklib_oci_delete_instance <id>
  mocklib_oci_create_vcn <cidr>
  mocklib_oci_list_vcns
  mocklib_oci_create_volume <size_gb>
  mocklib_oci_list_volumes

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GCP Compute  (/gcp/compute/v1/projects/{project}/...)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mocklib_gcp_list_zones <project>
  mocklib_gcp_create_instance <project> <zone> <name> [machine_type]
  mocklib_gcp_list_instances <project> <zone>
  mocklib_gcp_delete_instance <project> <zone> <name>
  mocklib_gcp_start_instance <project> <zone> <name>
  mocklib_gcp_stop_instance <project> <zone> <name>
  mocklib_gcp_create_network <project> <name>
  mocklib_gcp_list_networks <project>
  mocklib_gcp_create_firewall <project> <name> <network> <protocol> <ports>
  mocklib_gcp_list_firewalls <project>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Azure  (/azure/subscriptions/{sub}/...)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mocklib_azure_list_resource_groups <subscription_id>
  mocklib_azure_create_resource_group <sub> <name> <location>
  mocklib_azure_create_vnet <sub> <rg> <name> <address_space>
  mocklib_azure_list_vnets <sub> <rg>
  mocklib_azure_delete_vnet <sub> <rg> <name>
  mocklib_azure_create_nsg <sub> <rg> <name>
  mocklib_azure_create_vm <sub> <rg> <name> [size] [image]
  mocklib_azure_list_vms <sub> <rg>
  mocklib_azure_get_vm <sub> <rg> <name>
  mocklib_azure_delete_vm <sub> <rg> <name>
  mocklib_azure_start_vm <sub> <rg> <name>
  mocklib_azure_stop_vm <sub> <rg> <name>         (powerOff)
  mocklib_azure_deallocate_vm <sub> <rg> <name>
  mocklib_azure_restart_vm <sub> <rg> <name>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Legacy Storage (backwards-compatible)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  mocklib_storage_create_bucket <name> [provider] [region]
  mocklib_storage_upload_object <bucket> <key> <data>
  mocklib_storage_delete_bucket <bucket>

Examples:
  mocklib_vpc_create "10.0.0.0/16"
  mocklib_ec2_run_instances "t3.micro" "ami-0abc1234" 2
  mocklib_lambda_create "my-func" "python3.11" 256 60
  mocklib_lambda_list
  mocklib_dynamodb_create_table "users" "user_id"
  mocklib_sqs_create_queue "my-queue"
  mocklib_sns_create_topic "alerts"
  mocklib_oci_list_buckets "my-namespace"
  mocklib_gcp_list_instances "my-project" "us-central1-a"
  mocklib_azure_list_vms "sub-id" "my-rg"
EOF
}

echo "mocklib-shell v1.0.0 loaded — run 'mocklib_help' for usage"
