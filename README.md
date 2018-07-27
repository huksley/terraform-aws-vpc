# Terraform AWS VPC scripts

Creates VPC on AWS with gateway and subnets configured.

## Example

```hcl
module "build_vpc" {
    source              = "github.com/huksley/terraform-aws-vpc?ref=1.0_GA"
    prefix              = "${var.namespace}-vpc-${var.stage}"
    aws_region          = "${var.aws_region}"
    aws_account_id      = "${var.aws_account_id}"
    az_count            = 2
}
```
