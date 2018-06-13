Generates VPC on AWS

```json
module "build_vpc" {
    source = "./aws-vpc"
    prefix              = "${var.namespace}-vpc-${var.stage}"
    aws_region          = "${var.aws_region}"
    aws_account_id      = "${var.aws_account_id}"
    az_count            = 2
}
```