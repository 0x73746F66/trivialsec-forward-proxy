locals {
    linode_default_region   = "ap-southeast"
    linode_default_image    = "linode/alpine3.14"
    linode_default_type     = "g6-standard-1"
    authorized_keys         = [
        var.public_key
    ]
}
