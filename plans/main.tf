terraform {
    required_providers {
        linode = {
            source = "linode/linode"
            version = "1.18.0"
        }
    }
    backend "s3" {
        bucket = "static-trivialsec"
        key    = "terraform/statefiles/forward-proxy"
        region  = "ap-southeast-2"
        profile = "trivialsec"
    }
}

provider "linode" {
    token = var.linode_token
}

provider "aws" {
    region              = local.aws_default_region
    secret_key          = var.aws_secret_access_key
    access_key          = var.aws_access_key_id
    allowed_account_ids = [local.aws_master_account_id]
}
