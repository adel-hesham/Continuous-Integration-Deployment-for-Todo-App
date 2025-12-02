output "vpc_name" {
  value = aws_vpc.main.id
}

output "nexus_ec2_private_ip" {
  value = aws_instance.my_nginx_ec2.private_ip
}
output "basion_host_ec2_public_dns" {
  value = aws_instance.basion_host_ec2.public_dns
}
output "public_subnet_ids" {
value = [
  aws_subnet.public_AZ1.id,
  aws_subnet.public_AZ2.id
]
 }
output "nexus_ec2_id" {
  value = aws_instance.my_nexus_ec2.id
}
