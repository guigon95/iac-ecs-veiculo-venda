# Create the internal application load balancer (ALB) in the private subnets.
resource "aws_lb" "ecs_alb" {
 name               = "Terraform-ECS-veiculovenda-ALB"
 security_groups    = [aws_security_group.lb_security_group.id]
 load_balancer_type = "application"
 internal = true
 subnets =  [for subnet in aws_subnet.veiculovenda-public-subnet : subnet.id]

}

# Create the ALB target group for ECS.
resource "aws_lb_target_group" "alb_ecs_tg" {
 name        = "ALB-TG-veiculovenda"
 port        = 80
 protocol    = "HTTP"
 target_type = "ip"
 vpc_id      = aws_vpc.veiculovenda-vpc.id


 health_check {
   healthy_threshold   = "3"
   interval            = "30"
   protocol            = "HTTP"
   matcher             = "200,301,302"
   path                = "/actuator/health"
   timeout             = "15"
   unhealthy_threshold = "5"
 }
}

# Create the ALB listener with the target group.
resource "aws_lb_listener" "ecs_alb_listener" {
 load_balancer_arn = aws_lb.ecs_alb.arn
 port              = 80
 protocol          = "HTTP"

 default_action {
   type             = "forward"
   target_group_arn = aws_lb_target_group.alb_ecs_tg.arn
 }
}