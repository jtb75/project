###########################################################
## Configure role, policy, cloudwatch group, and flow logs
###########################################################

resource "aws_iam_role" "mongo_flow_role" {
  name = "mongo_flow_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "mongo_flow_policy" {
  name = "mongo_flow_policy"
  role = aws_iam_role.mongo_flow_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_flow_log" "mongo_flow" {
  iam_role_arn    = aws_iam_role.mongo_flow_role.arn
  log_destination = aws_cloudwatch_log_group.mongo_flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = module.vpc.vpc_id
}

resource "aws_cloudwatch_log_group" "mongo_flow_log" {
  name              = "mongo_flow_log-${random_string.suffix.id}"
  retention_in_days = 1
}

###########################################################
## SSM Role, Policy, Attachment, and attach to Mongo
## Instance
###########################################################

resource "aws_iam_role" "mongo_ec2" {
  name = "risky_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "mongo_ec2" {
  name = "risky_policy"
  role = aws_iam_role.mongo_ec2.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:*",
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "mongo_attach" {
  role       = aws_iam_role.mongo_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_instance_profile" "mongo_profile" {
  name = "ssm_mgr_policy"
  role = aws_iam_role.mongo_ec2.name
}

###########################################################
## Build Mongo EC2 Instance
###########################################################

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "mongo-${random_string.suffix.result}"

  ami           = "ami-08d4ac5b634553e16"
  instance_type = "t2.micro"
  key_name      = var.key_pair
  monitoring    = true
  vpc_security_group_ids = [
    aws_security_group.allow_mongo.id,
    aws_security_group.allow_ssh.id,
  ]
  count                = 1
  subnet_id            = module.vpc.public_subnets[count.index]
  iam_instance_profile = aws_iam_instance_profile.mongo_profile.name

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }

  user_data = <<-EOF
    #!/bin/bash
    EOF
}


