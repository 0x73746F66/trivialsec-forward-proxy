SHELL := /bin/bash
-include .env
export $(shell sed 's/=.*//' .env)
.ONESHELL: # Applies to every targets in the file!
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

upload: ## Send squid.conf and allowed-sites.txt to S3
ifdef AWS_PROFILE
	aws --profile $(AWS_PROFILE) s3 cp --only-show-errors conf/allowed-sites.txt s3://static-trivialsec/deploy-packages/allowed-sites.txt
	aws --profile $(AWS_PROFILE) s3 cp --only-show-errors conf/squid.conf s3://static-trivialsec/deploy-packages/squid.conf
else
	aws s3 cp --only-show-errors conf/allowed-sites.txt s3://static-trivialsec/deploy-packages/allowed-sites.txt
	aws s3 cp --only-show-errors conf/squid.conf s3://static-trivialsec/deploy-packages/squid.conf
endif

tfinstall:
	curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
	sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(shell lsb_release -cs) main"
	sudo apt-get update
	sudo apt-get install -y terraform
	terraform -install-autocomplete || true

init:  ## Runs tf init tf
	cd plans
	terraform init -reconfigure -upgrade=true

plan: init ## Runs tf validate and tf plan
	cd plans
	terraform init -reconfigure -upgrade=true
	terraform validate
	terraform plan -no-color -out=.tfplan
	terraform show --json .tfplan | jq -r '([.resource_changes[]?.change.actions?]|flatten)|{"create":(map(select(.=="create"))|length),"update":(map(select(.=="update"))|length),"delete":(map(select(.=="delete"))|length)}' > tfplan.json

apply: plan ## tf apply -auto-approve -refresh=true
	cd plans
	terraform apply -auto-approve -refresh=true .tfplan

tail-access: ## tail the squid access log in prod
	ssh root@proxy.trivialsec.com tail -f /var/log/squid/access.log

destroy: init ## tf destroy -auto-approve
	cd plans
	terraform validate
	terraform plan -destroy -no-color -out=.tfdestroy
	terraform show --json .tfdestroy | jq -r '([.resource_changes[]?.change.actions?]|flatten)|{"create":(map(select(.=="create"))|length),"update":(map(select(.=="update"))|length),"delete":(map(select(.=="delete"))|length)}' > tfdestroy.json
	terraform apply -auto-approve -destroy .tfdestroy