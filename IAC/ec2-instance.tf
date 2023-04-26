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

resource "aws_iam_role" "ssm_role_tf" {
  name = "ssm_role_tf_${random_string.suffix.id}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }
}
EOF
}

resource "aws_iam_role_policy_attachment" "role_attach" {
  role       = aws_iam_role.ssm_role_tf.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_instance_profile" "ssm_mgr_policy" {
  name = "ssm_mgr_tf_${random_string.suffix.id}"
  role = aws_iam_role.ssm_role_tf.name
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

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh_sg"
  description = "Allow SSH inbound connections"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_ip
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_sg"
  }
}

resource "aws_security_group" "allow_mongo" {
  name        = "allow_mongo_sg"
  description = "Allow Mongo inbound connections"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = var.admin_ip
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_mongo_sg"
  }
}

resource "aws_security_group" "allow_outbound" {
  name        = "allow_outbound_sg"
  description = "Allow outbound connections"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_outbound_sg"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = module.vpc.vpc_id

  ingress {
    protocol  = -1
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
  }

}

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
    set -ex
    sudo apt update
    sudo apt install -y wget curl gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release unzip
    wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add -
    curl -fsSL https://www.mongodb.org/static/pgp/server-5.0.asc|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/mongodb.gpg
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $( lsb_release -cs)/mongodb-org/5.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list
    sudo apt update
    sudo apt install -y mongodb-org
    sudo apt-get install -y --allow-downgrades mongodb-org=5.0.17 mongodb-org-database=5.0.17 mongodb-org-server=5.0.17 mongodb-org-shell=5.0.17 mongodb-org-mongos=5.0.17 mongodb-org-tools=5.0.17
    sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/g' /etc/mongod.conf
    sudo systemctl start mongod
    sudo systemctl enable mongod
    sudo sed -i 's/#security:/security:\n  authorization: enabled/g' /etc/mongod.conf
    echo dXNlIGFkbWluCmRiLmNyZWF0ZVVzZXIoIHsgdXNlcjogJ2RidXNlcicgLCBwd2Q6ICdwYXNzd29yZDEyMycsIHJvbGVzOiBbICd1c2VyQWRtaW5BbnlEYXRhYmFzZScsICdkYkFkbWluQW55RGF0YWJhc2UnLCAncmVhZFdyaXRlQW55RGF0YWJhc2UnIF0gfSkK | base64 -d > /tmp/create.js
    sudo mongosh --eval < /tmp/create.js
    sudo systemctl restart mongod
    sudo ufw allow from 0.0.0.0 to any port 27017
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -fr aws awscliv2.zip
    echo IyEvYmluL3NoIC14CgpleHBvcnQgSE9NRT0vaG9tZS91YnVudHUvCgpIT1NUPWxvY2FsaG9zdAoKIyBEQiBuYW1lCkRCTkFNRT1mbGFza19kYgoKIyBTMyBidWNrZXQgbmFtZQpCVUNLRVQ9YC91c3IvbG9jYWwvYmluL2F3cyBzMyBscyB8IGdyZXAgIiBwcm9qZWN0LWJhY2t1cC0iIHwgY3V0IC1kICIgIiAtZjNgCgojIExpbnV4IHVzZXIgYWNjb3VudApVU0VSPXVidW50dQoKIyBDdXJyZW50IHRpbWUKVElNRT1gL2Jpbi9kYXRlICslZC0lbS0lWS0lVGAKCiMgQmFja3VwIGRpcmVjdG9yeQpERVNUPS9ob21lLyRVU0VSL3RtcAoKIyBUYXIgZmlsZSBvZiBiYWNrdXAgZGlyZWN0b3J5ClRBUj0kREVTVC8uLi8kVElNRS50YXIKCiMgQ3JlYXRlIGJhY2t1cCBkaXIgKC1wIHRvIGF2b2lkIHdhcm5pbmcgaWYgYWxyZWFkeSBleGlzdHMpCi9iaW4vbWtkaXIgLXAgJERFU1QKCiMgTG9nCmVjaG8gIkJhY2tpbmcgdXAgJEhPU1QvJERCTkFNRSB0byBzMzovLyRCVUNLRVQvIG9uICRUSU1FIjsKCiMgRHVtcCBmcm9tIG1vbmdvZGIgaG9zdCBpbnRvIGJhY2t1cCBkaXJlY3RvcnkKL3Vzci9iaW4vbW9uZ29kdW1wIC1oICRIT1NUIC1kICREQk5BTUUgLW8gJERFU1QgLXUgZGJ1c2VyIC1wIHBhc3N3b3JkMTIzIC0tYXV0aGVudGljYXRpb25EYXRhYmFzZT1hZG1pbgoKIyBDcmVhdGUgdGFyIG9mIGJhY2t1cCBkaXJlY3RvcnkKL2Jpbi90YXIgY3ZmICRUQVIgLUMgJERFU1QgLgoKIyBVcGxvYWQgdGFyIHRvIHMzCi91c3IvbG9jYWwvYmluL2F3cyBzMyBjcCAkVEFSIHMzOi8vJEJVQ0tFVC8gLS1zdG9yYWdlLWNsYXNzIFNUQU5EQVJEX0lBCgojIFJlbW92ZSB0YXIgZmlsZSBsb2NhbGx5Ci9iaW4vcm0gLWYgJFRBUgoKIyBSZW1vdmUgYmFja3VwIGRpcmVjdG9yeQovYmluL3JtIC1yZiAkREVTVAoKIyBBbGwgZG9uZQplY2hvICJCYWNrdXAgYXZhaWxhYmxlIGF0IGh0dHBzOi8vczMuYW1hem9uYXdzLmNvbS8kQlVDS0VULyRUSU1FLnRhciIKCg== | base64 -d > /tmp/backup-mongo
    sudo mv /tmp/mongo-backup.sh /etc/cron.daily/mongo-backup
    sudo chmod 755 /etc/cron.daily/mongo-backup
    EOF
}

