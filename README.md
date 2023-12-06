# aws-bedrock-playground

CloudFormation templates, scripts, configs and notes for working with Amazon Bedrock.

## Prerequisites

* Bucket stacks from [sjakthol/aws-account-infra](https://github.com/sjakthol/aws-account-infra).

## Knowledge Bases

Setup:

```bash
# Create infra (S3 bucket, Amazon OpenSearch Serverless collection, IAM Roles etc.) for Amazon Bedrock Knowledge Bases
make deploy-kb-infra

# Create index for vector data in AOSS (requires awscurl)
make create-vector-index

# Create knowledge base in Bedrock
make create-knowledge-base create-data-source
```

Cleanup:

```bash
# Delete knowledge base from Bedrock
make delete-knowledge-base

# Delete infra
make delete-kb-infra
```

## License

MIT.
