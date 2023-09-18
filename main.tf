provider "aws" {
  region = "eu-central-1"
  #Man sollte für CodeBuild einen eigenen IAM User erstellen
  profile = "codebuild-user" #Hier iam benutzer
}

#Der ganze restliche Aufbau ab hier
terraform {
  backend "s3" {
    bucket  = "terraform-tfstate-speicher-fuer-pipeline-123"
    key     = "build/terraform.tfstate"
    region  = "eu-central-1"
    profile = "build-benutzer"
  }
}
