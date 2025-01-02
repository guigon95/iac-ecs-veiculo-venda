# Create the ECS Cluster and Fargate launch type service in the private subnets
resource "aws_ecs_cluster" "ecs_cluster" {
 name = var.cluster_name
}

resource "aws_ecs_task_definition" "ecs_task_def" {
 family                   = var.cluster_task
 container_definitions    = <<DEFINITION
 [
   {
     "name": "${var.cluster_task}",
     "image": "${aws_ecr_repository.veiculovenda.repository_url}:latest",
     "environment": [
     {
        "name": "aws.key",
        "value": "${var.access_key}"
     },
     {
        "name": "aws.secret",
        "value": "${var.secret_key}"
     }
     ],
      "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
               "awslogs-group" : "ecs-logs",
               "awslogs-region": "us-east-2",
               "awslogs-stream-prefix": "ecs"
            }
      },
     "essential": true,
     "portMappings": [
       {
         "containerPort": ${var.container_port},
         "hostPort": ${var.container_port}
       }
     ],
     "memory": ${var.memory},
     "cpu": ${var.cpu}
   }
 ]
 DEFINITION
 requires_compatibilities = ["FARGATE"]
 network_mode             = "awsvpc"
 memory                   = var.memory
 cpu                      = var.cpu
 execution_role_arn       = aws_iam_role.ecs_task_exec_role.arn
}


resource "aws_iam_role" "ecs_task_exec_role" {
 name               = "ecs_task_exec_role_veiculovenda"
 assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}


data "aws_iam_policy_document" "assume_role_policy" {
 statement {
   actions = ["sts:AssumeRole"]


   principals {
     type        = "Service"
     identifiers = ["ecs-tasks.amazonaws.com"]
   }
 }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
 role       = aws_iam_role.ecs_task_exec_role.name
 policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_service" "veiculo-service-ecs-service" {
 name                = var.cluster_service
 cluster             = aws_ecs_cluster.ecs_cluster.id
 task_definition     = aws_ecs_task_definition.ecs_task_def.arn
 launch_type         = "FARGATE"
 ##scheduling_strategy = "REPLICA"
 desired_count       = var.desired_capacity
 depends_on      = [aws_lb_target_group.alb_ecs_tg, aws_lb_listener.ecs_alb_listener]


 load_balancer {
   target_group_arn = aws_lb_target_group.alb_ecs_tg.arn
   container_name   = aws_ecs_task_definition.ecs_task_def.family
   container_port   = var.container_port
 }


 network_configuration {
   subnets          = [for subnet in aws_subnet.veiculovenda-private-subnet : subnet.id]
   security_groups  = [aws_security_group.ecs_security_group.id]
 }
}

# Create the VPC Link configured with the private subnets. Security groups are kept empty here, but can be configured as required.
resource "aws_apigatewayv2_vpc_link" "vpclink_apigw_to_alb" {
  name        = "vpclink_apigw_to_alb"
  security_group_ids = []

  subnet_ids = [for subnet in aws_subnet.veiculovenda-public-subnet : subnet.id]
}

# IGW for the public subnet
resource "aws_internet_gateway" "veiculovenda-internet-gateway" {
  vpc_id = aws_vpc.veiculovenda-vpc.id
}

# Route the public subnet traffic through the IGW
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.veiculovenda-vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.veiculovenda-internet-gateway.id}"
}

# Create a NAT gateway with an EIP for each private subnet to get internet connectivity
resource "aws_eip" "gw" {
  count      = 2
  domain        = "vpc"
  depends_on = [aws_internet_gateway.veiculovenda-internet-gateway]
}

resource "aws_nat_gateway" "veiculo-service-nat-gateway" {
  count      = 2
  subnet_id     = "${element(aws_subnet.veiculovenda-public-subnet.*.id, count.index)}"
  allocation_id = "${element(aws_eip.gw.*.id, count.index)}"
}

# Create a new route table for the private subnets
# And make it route non-local traffic through the NAT gateway to the internet
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.veiculovenda-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.veiculo-service-nat-gateway.*.id, count.index)}"
  }
}

# Explicitely associate the newly created route tables to the private subnets (so they don't default to the main route table)
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = "${element(aws_subnet.veiculovenda-private-subnet.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}