provider "aws" {
  region = "ap-south-1"
}

# Generate a new SSH key pair
resource "tls_private_key" "new_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create a key pair in AWS using the generated public key
resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "ec2_key_pair"
  public_key = tls_private_key.new_key_pair.public_key_openssh
}

# Create an ECS cluster
resource "aws_ecs_cluster" "ecs_poc_cluster" {
  name = "ecs_poc_cluster"
}

# Create a VPC
resource "aws_vpc" "ecs_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "ecs_vpc"
  }
}

# Create subnets
resource "aws_subnet" "ecs_vpc" {
  count             = 2
  vpc_id            = aws_vpc.ecs_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.ecs_vpc.cidr_block, 8, count.index)
  availability_zone = element(["ap-south-1a", "ap-south-1b"], count.index)
  tags = {
    Name = "ecs_vpc-subnet-${count.index}"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "ecs_vpc" {
  vpc_id = aws_vpc.ecs_vpc.id
  tags = {
    Name = "ecs_vpc-igw"
  }
}

# Create a route table
resource "aws_route_table" "ecs_vpc" {
  vpc_id = aws_vpc.ecs_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ecs_vpc.id
  }
  tags = {
    Name = "ecs_vpc-route-table"
  }
}

# Associate subnets with route table
resource "aws_route_table_association" "ecs_vpc" {
  count          = 2
  subnet_id      = element(aws_subnet.ecs_vpc.*.id, count.index)
  route_table_id = aws_route_table.ecs_vpc.id
}

# Create a security group
resource "aws_security_group" "ecs_vpc" {
  name        = "ecs_poc_sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.ecs_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs_poc_sg"
  }
}

# Create IAM Roles and Policies
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com",
        },
        Action = "sts:AssumeRole",
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com",
        },
        Action = "sts:AssumeRole",
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

# Create EC2 instances to serve as the ECS container instances
resource "aws_instance" "ecs_instance" {
  count         = 2
  ami           = "ami-08ebc9e780cde07dd"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  subnet_id     = element(aws_subnet.ecs_vpc.*.id, count.index)
  key_name      = aws_key_pair.ec2_key_pair.key_name

  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.ecs_vpc.id]

  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              echo ECS_CLUSTER=${aws_ecs_cluster.ecs_poc_cluster.name} >> /etc/ecs/ecs.config
              yum update -y
              amazon-linux-extras install ecs -y
              systemctl start ecs
              EOF

  tags = {
    Name = "ecs_instance-${count.index}"
  }
}

# Create an ECS task definition
resource "aws_ecs_task_definition" "ecs_poc_task" {
  family                   = "ecs_poc_task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "demo-app"
      image     = "nginx:1.25.5"
      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

# Create an ECS service
resource "aws_ecs_service" "ecs_poc_service" {
  name            = "ecs_poc_service"
  cluster         = aws_ecs_cluster.ecs_poc_cluster.id
  task_definition = aws_ecs_task_definition.ecs_poc_task.arn
  desired_count   = 1
  launch_type     = "EC2"

  tags = {
    Name = "ecs_poc_service"
  }
}

# Output the ECS Cluster name
output "ecs_cluster_name" {
  value = aws_ecs_cluster.ecs_poc_cluster.name
}

# Output the ECS Service name
output "ecs_service_name" {
  value = aws_ecs_service.ecs_poc_service.name
}

# Output the ECS Task Definition ARN
output "ecs_task_definition_arn" {
  value = aws_ecs_task_definition.ecs_poc_task.arn
}

# Output the EC2 instance Public IPs
output "ecs_instance_public_ips" {
  value = aws_instance.ecs_instance.*.public_ip
}

# Output the VPC ID
output "vpc_id" {
  value = aws_vpc.ecs_vpc.id
}

# Output the Subnet IDs
output "subnet_ids" {
  value = aws_subnet.ecs_vpc.*.id
}

# Output the Security Group ID
output "security_group_id" {
  value = aws_security_group.ecs_vpc.id
}

# Output the Key Pair file path
output "key_pair_file" {
  value = local_file.private_key_pem.filename
}

# Save the private key locally
resource "local_file" "private_key_pem" {
  content  = tls_private_key.new_key_pair.private_key_pem
  filename = "${path.module}/ec2_key_pair.pem"
  provisioner "local-exec" {
    command = "chmod 400 ${path.module}/ec2_key_pair.pem"
  }
}
