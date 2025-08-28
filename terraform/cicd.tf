# --- Repositório no AWS CodeCommit ---
resource "aws_codecommit_repository" "main" {
  repository_name = "${var.project_name}-repo"
  description     = "Repositório para o Desafio DevOps"
  tags = {
    Name        = "${var.project_name}-repo"
    Environment = var.environment
  }
}

# --- IAM Role para o CodeBuild ---
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.project_name}-codebuild-policy"
  role = aws_iam_role.codebuild_role.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.project_name}-*"]
      },
      {
        Effect   = "Allow"
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# --- Projetos do CodeBuild ---
resource "aws_codebuild_project" "api" {
  name          = "${var.project_name}-build-api"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "10" # minutos

  artifacts { type = "NO_ARTIFACTS" }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
    environment_variable {
      name  = "REPOSITORY_URI"
      value = aws_ecr_repository.api.repository_url
    }
  }
  source {
    type      = "CODECOMMIT"
    location  = aws_codecommit_repository.main.clone_url_http
    buildspec = "api/buildspec.yml"
  }
  tags = { Name = "${var.project_name}-build-api" }
}

resource "aws_codebuild_project" "nginx" {
  name          = "${var.project_name}-build-nginx"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "10"

  artifacts { type = "NO_ARTIFACTS" }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
    environment_variable {
      name  = "REPOSITORY_URI"
      value = aws_ecr_repository.nginx.repository_url
    }
  }
  source {
    type      = "CODECOMMIT"
    location  = aws_codecommit_repository.main.clone_url_http
    buildspec = "nginx/buildspec.yml"
  }
  tags = { Name = "${var.project_name}-build-nginx" }
}


# --- IAM Role para o CodePipeline ---
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-codepipeline-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.project_name}-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketVersioning",
            "s3:PutObjectAcl",
            "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["codecommit:GetBranch", "codecommit:GetCommit", "codecommit:UploadArchive", "codecommit:GetUploadArchiveStatus", "codecommit:CancelUploadArchive"]
        Resource = [aws_codecommit_repository.main.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["codebuild:StartBuild", "codebuild:BatchGetBuilds"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecs:DescribeServices", "ecs:UpdateService"]
        Resource = [aws_ecs_service.api.id, aws_ecs_service.nginx.id]
      }
    ]
  })
}

# --- S3 Bucket para Artefatos do Pipeline ---
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "${var.project_name}-codepipeline-artifacts-${data.aws_caller_identity.current.account_id}"
}

# --- AWS CodePipeline ---
resource "aws_codepipeline" "main" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.id
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName = aws_codecommit_repository.main.repository_name
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name            = "Build-API"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]
      configuration = {
        ProjectName = aws_codebuild_project.api.name
      }
    }
    action {
      name            = "Build-Nginx"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]
      configuration = {
        ProjectName = aws_codebuild_project.nginx.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy-API-to-ECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["source_output"]
      configuration = {
        ClusterName = aws_ecs_cluster.main.name
        ServiceName = aws_ecs_service.api.name
      }
    }
    action {
      name            = "Deploy-Nginx-to-ECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["source_output"]
      configuration = {
        ClusterName = aws_ecs_cluster.main.name
        ServiceName = aws_ecs_service.nginx.name
      }
    }
  }
}

# --- Data source para obter o ID da conta ---
data "aws_caller_identity" "current" {}
