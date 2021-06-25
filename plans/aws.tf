resource "aws_ssm_parameter" "ssm_root_password" {
  name        = "/terraform/linode/root_password/${linode_instance.forward_proxy.id}"
  description = join(", ", linode_instance.forward_proxy.ipv4)
  type        = "SecureString"
  value       = random_string.linode_root_password.result
  tags = {
    cost-center = "saas"
  }
}
resource "aws_route53_record" "proxy_ipv4" {
    zone_id = local.hosted_zone
    name    = "proxy.${local.apex_domain}"
    type    = "A"
    ttl     = 300
    records = linode_instance.forward_proxy.ipv4
}
resource "aws_route53_record" "proxy_ipv6" {
    zone_id = local.hosted_zone
    name    = "proxy.${local.apex_domain}"
    type    = "AAAA"
    ttl     = 300
    records = [trimsuffix(linode_instance.forward_proxy.ipv6, "/128")]
}