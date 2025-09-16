# LinkProject

1) Run "Terraform apply" first then run where .tfstate file is present---->
     "terraform output -raw env_file_content > /home/ubuntu/LinkProject/backend/.env"
so that the output of rds is written on .env file.


2) the terraform taint command, which marks a resource for replacement on the next terraform apply.

Mark the instance for replacement:
terraform taint aws_instance.link_ec2

Apply the changes:
terraform apply
