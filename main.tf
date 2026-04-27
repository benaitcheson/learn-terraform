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

resource "aws_s3_bucket" "example" {
  bucket = "bucket-${random_pet.bucket_suffix.id}"

  tags = {
    Name = "bucket-${random_pet.bucket_suffix.id}"
  }
}

resource "aws_instance" "web_server" {
  ami           = "ami-098e39bafa7e7303d"
  instance_type = "t2.micro"

  tags = {
    Name = "server-${random_pet.bucket_suffix.id}"
  }
}

resource "aws_db_instance" "postgres" {
  identifier          = "primary-instance-${random_pet.bucket_suffix.id}"
  engine              = "postgres"
  engine_version      = "17.9"
  instance_class      = "db.t4g.micro"
  allocated_storage   = 20
  storage_type        = "gp3"
  db_name             = "mydb"
  username            = "unxkqzmpltbac"
  password            = random_password.db_password.result
  skip_final_snapshot = true
  publicly_accessible = false
}
