provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "random_pet" "bucket_suffix" {
  length = 2
}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"
}

resource "aws_security_group" "web_server" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_iam_role" "web_server_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "web_server_role_policy_attachment" {
  role       = aws_iam_role.web_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web_server_profile" {
  role = aws_iam_role.web_server_role.name
}

resource "aws_s3_bucket" "example" {
  bucket = "bucket-${random_pet.bucket_suffix.id}"

  tags = {
    Name = "bucket-${random_pet.bucket_suffix.id}"
  }
}

resource "aws_instance" "web_server" {
  ami           = "ami-098e39bafa7e7303d"
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.web_server_profile.name
  vpc_security_group_ids = [aws_security_group.web_server.id]

  tags = {
    Name = "server-${random_pet.bucket_suffix.id}"
  }
}

resource "aws_db_instance" "postgres" {
  identifier          = "primary-instance-${random_pet.bucket_suffix.id}"
  engine              = "postgres"
  engine_version      = "18.3"
  instance_class      = "db.t4g.micro"
  allocated_storage   = 20
  storage_type        = "gp3"
  db_name             = "mydb"
  username            = "unxkqzmpltbac"
  password            = random_password.db_password.result
  skip_final_snapshot = true
  publicly_accessible = false
}
