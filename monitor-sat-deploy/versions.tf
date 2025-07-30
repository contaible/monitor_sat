# Terraform version constraints

terraform {
  required_version = ">= 1.0"


  # Backend configuration for state management (opcional)
  # Uncomment and configure for production use
  /*
  backend "s3" {
    bucket = "tu-bucket-terraform-state"
    key    = "monitor-sat/terraform.tfstate"
    region = "us-east-2"
    
    # Optional: DynamoDB table for state locking
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
  */
}