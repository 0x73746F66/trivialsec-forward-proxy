data "linode_profile" "me" {}
data "local_file" "alpine_squid" {
    filename = "${path.root}/../bin/alpine-squid"
}
resource "random_string" "linode_root_password" {
    length  = 32
    special = true
}
resource "linode_stackscript" "squid" {
  label = "squid"
  description = "Installs squid"
  script = data.local_file.alpine_squid.content
  images = [local.linode_default_image]
}
resource "linode_instance" "forward_proxy" {
  label             = "forward-proxy"
  group             = "SaaS"
  tags              = ["SaaS"]
  region            = local.linode_default_region
  type              = local.linode_default_type
  image             = local.linode_default_image
  authorized_keys   = length(var.public_key) == 0 ? [] : [
    var.public_key
  ]
  authorized_users  = [
    data.linode_profile.me.username,
    "chrislangton"
  ]
  root_pass         = random_string.linode_root_password.result
  stackscript_id    = linode_stackscript.squid.id
  stackscript_data  = {
    "AWS_ACCESS_KEY_ID" = var.aws_access_key_id
    "AWS_SECRET_ACCESS_KEY" = var.aws_secret_access_key
  }
  alerts {
      cpu            = 90
      io             = 10000
      network_in     = 10
      network_out    = 10
      transfer_quota = 80
  }
}