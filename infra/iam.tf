data "aws_caller_identity" "atual" {}

########################################
# Role da EC2: puxar do ECR + agente SSM
########################################

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${local.nome}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Permite que o GitHub Actions mande comandos de deploy via Systems Manager.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Permite o docker pull do ECR sem guardar senha na instancia.
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.nome}-ec2-profile"
  role = aws_iam_role.ec2.name
}

########################################
# Usuario IAM consumido pelo GitHub Actions
########################################

resource "aws_iam_user" "ci" {
  name = "${local.nome}-github-actions"
  path = "/ci/"

  tags = { Repositorio = var.github_repo }
}

data "aws_iam_policy_document" "ci" {
  # Login no registry: nao aceita recurso especifico.
  statement {
    sid       = "LoginNoECR"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Push e pull restritos ao repositorio deste projeto.
  statement {
    sid = "PushNoRepositorioDoProjeto"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.app.arn]
  }

  # Deploy: so pode rodar o documento de shell e so nesta instancia.
  statement {
    sid     = "DeployViaSSM"
    actions = ["ssm:SendCommand"]
    resources = [
      "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
      aws_instance.portal.arn,
    ]
  }

  # Acompanhar o resultado do comando de deploy.
  statement {
    sid = "AcompanharDeploy"
    actions = [
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
    ]
    resources = ["*"]
  }

  # Descobrir o IP publico para o smoke test final do pipeline.
  statement {
    sid       = "DescobrirIpDaInstancia"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "ci" {
  name   = "${local.nome}-ci-policy"
  user   = aws_iam_user.ci.name
  policy = data.aws_iam_policy_document.ci.json
}

resource "aws_iam_access_key" "ci" {
  user = aws_iam_user.ci.name
}
