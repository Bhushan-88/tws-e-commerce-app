```bash
terraform/terra-automate-key
terraform/terra-automate-key.pub

terraform -chdir=terraform plan \
  -target=module.vpc \
  -target=aws_instance.jenkins \
  -target=aws_secretsmanager_secret.postgres

  terraform apply \
  -target=module.vpc \
  -target=aws_instance.jenkins \
  -target=aws_secretsmanager_secret.postgres
  
-------------------Destroy----------------------
  terraform plan -destroy \
  -target=aws_instance.jenkins \
  -target=aws_secretsmanager_secret.postgres \
  -target=module.vpc

  terraform destroy \
  -target=aws_instance.jenkins \
  -target=aws_secretsmanager_secret.postgres \
  -target=module.vpc