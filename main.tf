provider "aws" {
  region = "eu-central-1"
  #Man sollte für CodeBuild einen eigenen IAM User erstellen
  profile = "codebuild-user"
}

#Der ganze restliche Aufbau
#VPCS UND SUBNETZE
#_________________________
# VPC erstellen und IGW hinzufügen
resource "aws_vpc" "vpc-lulu" {
  cidr_block = "10.0.0.0/16"
}

# Öffentliches Subnetz erstellen
resource "aws_subnet" "subnetz-oeffentlich" {
  vpc_id                  = aws_vpc.vpc-lulu.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"  
}

# Privates Subnetz erstellen
resource "aws_subnet" "subnetz-privat" {
  vpc_id                  = aws_vpc.vpc-lulu.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-central-1a"  
}

# Internet Gateway für öffentlichen Zugriff erstellen
# Und an den VPC Attachen
resource "aws_internet_gateway" "lulu_igw" {
  vpc_id = aws_vpc.vpc-lulu.id
}
#_________________________


#ROUTING TABELLEN UND SUBNETZ-ZUWEISUNGEN
#_________________________
# Öffentliche Routing-Tabelle erstellen und IGW hinzufügen
resource "aws_route_table" "routing_table_oeffentlich" {
  vpc_id = aws_vpc.vpc-lulu.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.lulu_igw.id}"
  }
}


# Private Routing-Tabelle erstellen
resource "aws_route_table" "routing_table_privat" {
  vpc_id = aws_vpc.vpc-lulu.id
}

# Verknüpfung der öffentlichen Routing-Tabelle mit dem öffentlichen Subnetz
resource "aws_route_table_association" "lulu-oeffentlich-rt-regel" {
  subnet_id      = aws_subnet.subnetz-oeffentlich.id
  route_table_id = aws_route_table.routing_table_oeffentlich.id
}

# Verknüpfung der privaten Routing-Tabelle mit dem privaten Subnetz
resource "aws_route_table_association" "lulu-private-rt-regel" {
  subnet_id      = aws_subnet.subnetz-privat.id
  route_table_id = aws_route_table.routing_table_privat.id
}
#_________________________


# S3-Bucket erstellen
resource "aws_s3_bucket" "name_bucket" {
  bucket = "lulubuckettest"
}


#SECURITY GROUPS FOR EC2
#______________________________
#Security Group für SSH-Zugriff erstellen
resource "aws_security_group" "lulu_sg_oeffentlich" {
  vpc_id = aws_vpc.vpc-lulu.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" #gesamter datenverkehr
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" #gesamter datenverkehr
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "lulu_sg_oeffentlich"
  }
}

resource "aws_security_group" "lulu_sg_privat" {
  vpc_id = aws_vpc.vpc-lulu.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" #gesamter datenverkehr
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" #gesamter datenverkehr
    cidr_blocks = ["10.0.1.0/24"] #nur vom oeffentlichen subnetz
  }
  tags = {
    Name = "lulu_sg_privat"
  }
}
#______________________________


#IAM ROLLEN FÜR S3 BUCKETS 
#https://www.sammeechward.com/s3-and-iam-with-terraform
#bearbeitet mit:
#https://registry.terraform.io/modules/mineiros-io/iam-policy/aws/latest/examples/iam-policy-s3-full-access
#(damit die private EC2 Instanz auf Buckets zugreifen kann)
resource "aws_iam_policy" "lulu_bucket_regeln" {
  name        = "lulu-iam-bucket-zugriff-regeln"
  path        = "/"
  description = "Allow "

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : ["s3:*"],
        "Resource" : ["*"]
      }
    ]
  })
}

resource "aws_iam_role" "lulu_bucket_rolle" {
  name = "lulu-bucket-iam-rolle"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

#Jetzt können wir die Regeln zur Rolle hinzufügen
resource "aws_iam_role_policy_attachment" "some_bucket_policy" {
  role       = aws_iam_role.lulu_bucket_rolle.name
  policy_arn = aws_iam_policy.lulu_bucket_regeln.arn
}

#Um eine rolle zu einer EC2 Instanz hinzufügen zu können
#Brauchen wir ein "Instanz-Profil", welches die Rolle beinhaltet
resource "aws_iam_instance_profile" "lulu-bucket-iam-profil" {
  name = "lulu-bucket-iam-profil"
  role = aws_iam_role.lulu_bucket_rolle.name
}


resource "aws_instance" "lulu-ec2-oeffentlich" {
  ami           = "ami-0766f68f0b06ab145"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.subnetz-oeffentlich.id}"
  vpc_security_group_ids = ["${aws_security_group.lulu_sg_oeffentlich.id}"]
  associate_public_ip_address = true
  tags = {
    Name = "lulu-ec2-oeffentlich"
  }
  #vorhandenen schlüssel wählen
  key_name = "first_one"
}

resource "aws_instance" "lulu-ec2-privat" {
  ami           = "ami-0766f68f0b06ab145"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.subnetz-privat.id}"
  vpc_security_group_ids = ["${aws_security_group.lulu_sg_privat.id}"]
  iam_instance_profile = aws_iam_instance_profile.lulu-bucket-iam-profil.id
  tags = {
    Name = "lulu-ec2-privat"
  }
  key_name = "second_one"
}


#VPC Endpoint aufbauen
resource "aws_vpc_endpoint" "lulu-s3-vpc-endpoint" {
  vpc_id          = aws_vpc.vpc-lulu.id
  service_name    = "com.amazonaws.eu-central-1.s3"
  #zur privaten routing tabelle hinzufügen
  route_table_ids = ["${aws_route_table.routing_table_privat.id}"]

  tags = {
    Name = "lulu-s3-vpc-endpoint"
  }
}