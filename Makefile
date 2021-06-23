SHELL := /bin/bash
-include .env
export $(shell sed 's/=.*//' .env)
.ONESHELL: # Applies to every targets in the file!
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

CMD_AWS := aws
ifdef AWS_PROFILE
CMD_AWS += --profile $(AWS_PROFILE)
endif
ifdef AWS_REGION
CMD_AWS += --region $(AWS_REGION)
endif

upload:
	$(CMD_AWS) --profile trivialsec s3 cp --only-show-errors conf/allowed-sites.txt s3://static-trivialsec/deploy-packages/allowed-sites.txt
	$(CMD_AWS) --profile trivialsec s3 cp --only-show-errors conf/squid.conf s3://static-trivialsec/deploy-packages/squid.conf

plan:
	cd plans
	terraform init
	terraform init -upgrade=true
	terraform validate
	terraform plan -no-color -out=.tfplan

apply:
	cd plans
	terraform apply -auto-approve -refresh=true .tfplan
