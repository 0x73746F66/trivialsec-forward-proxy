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

