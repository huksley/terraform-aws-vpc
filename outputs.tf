output "aws_vpc_id" {
  value = "${join("", aws_vpc.main.*.id)}"
}

output "aws_security_group_id" {
  value = "${join("", aws_security_group.lb.*.id)}"
}

output "aws_private_subnet_ids" {
  value = "${aws_subnet.private.*.id}"
}

output "aws_public_subnet_ids" {
  value = "${aws_subnet.public.*.id}"
}
