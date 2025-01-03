resource "aws_ecr_repository" "veiculovenda" {
  name                 = "veiculo-venda"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}