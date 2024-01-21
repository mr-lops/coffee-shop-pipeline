TERRAFORM_BUCKET_NAME = my-terraform-bucket
PROJECT_BUCKET_NAME = my-project-bucket
REDSHIFT_PASSWORD = my-redshift-password
AWS_ACCOUNT_ID = $(shell aws sts get-caller-identity --query "Account" --output text)

all: myproject

myproject: dependencies terraform-bucket provide-resources create-dockerfile upload-data
	@read -p "Press any key to finish the project."
	@echo "Removing Resources..."
	@terraform -chdir=arch destroy -auto-approve
	@aws s3 rm s3://$(TERRAFORM_BUCKET_NAME) --recursive
	@aws s3 rb s3://$(TERRAFORM_BUCKET_NAME) --force
	@sed -i "s/$(TERRAFORM_BUCKET_NAME)/my-terraform-bucket/g" arch/main.tf
	@echo "Project Finished!"


dependencies:
	@echo "Dependencies Verification..."

	@if command -v terraform >/dev/null 2>&1; then \
    	echo "Terraform is installed"; \
	else \
    	echo "Terraform isn't installed!" >&2;  \
    	exit 1; \
	fi

	@if command -v aws >/dev/null 2>&1; then \
    	echo "AWSCLI is installed"; \
	else \
    	echo "AWSCLI isn't installed!" >&2;  \
    	exit 1; \
	fi

	@if command -v docker >/dev/null 2>&1; then \
    	echo "Docker is installed"; \
	else \
    	echo "Docker isn't installed!" >&2;  \
    	exit 1; \
	fi

terraform-bucket:
	@echo "Creating terraform bucket..."
	@aws s3api create-bucket --bucket $(TERRAFORM_BUCKET_NAME) --region us-east-1
	@sed -i "s/my-terraform-bucket/$(TERRAFORM_BUCKET_NAME)/g" arch/main.tf

provide-resources:
	@echo "Providing resources through Terraform..."
	@terraform -chdir=arch init
	@terraform -chdir=arch plan \
	-var="bucket_name=$(PROJECT_BUCKET_NAME)" \
	-var="master_password=$(REDSHIFT_PASSWORD)"
	@terraform -chdir=arch apply \
	-var="bucket_name=$(PROJECT_BUCKET_NAME)" \
	-var="master_password=$(REDSHIFT_PASSWORD)" -auto-approve

create-dockerfile:
	@echo "Creating docker image for ECR..."
	@aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.us-east-1.amazonaws.com
	@docker build -t ingest-data-repository .
	@docker tag ingest-data-repository:latest $(AWS_ACCOUNT_ID).dkr.ecr.us-east-1.amazonaws.com/ingest-data-repository:latest
	@docker push $(AWS_ACCOUNT_ID).dkr.ecr.us-east-1.amazonaws.com/ingest-data-repository:latest

upload-data:
	@echo "Uploading data to S3..."
	@aws s3 cp data s3://$(PROJECT_BUCKET_NAME)/ --recursive