provider "aws" {
  region = "ap-south-1"
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

# Create an ECS task definition
resource "aws_ecs_task_definition" "ecs_poc_task" {
  family                   = "ecs_poc_task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "example-app"
      image     = "nginx"
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
  desired_count   = 3
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = aws_subnet.ecs_vpc.*.id
    security_groups = [aws_security_group.ecs_vpc.id]
  }
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

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

