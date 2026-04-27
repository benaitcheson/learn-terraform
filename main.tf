provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "random_pet" "bucket_suffix" {
  length = 2
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
