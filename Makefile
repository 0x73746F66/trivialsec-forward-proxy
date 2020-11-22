SHELL := /bin/bash
-include .env
export $(shell sed 's/=.*//' .env)

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
	$(CMD_AWS) s3 cp --only-show-errors allowed-sites.txt s3://cloudformation-trivialsec/deploy-packages/allowed-sites.txt
	$(CMD_AWS) s3 cp --only-show-errors squid.conf s3://cloudformation-trivialsec/deploy-packages/squid.conf
