# Mapping from long region names to shorter ones that is to be
# used in the stack names
AWS_us-west-2_PREFIX = uw2

# Some defaults
AWS ?= aws
AWS_REGION = us-west-2
AWS_ACCOUNT_ID = $(eval AWS_ACCOUNT_ID := $(shell $(AWS_CMD) sts get-caller-identity --query Account --output text))$(AWS_ACCOUNT_ID)
DEPLOYER_ARN = $(eval DEPLOYER_ARN := $(shell $(AWS_CMD) sts get-caller-identity --query Arn --output text))$(DEPLOYER_ARN)

AWS_CMD := $(AWS) --region $(AWS_REGION)

STACK_NAME_PREFIX := $(AWS_$(AWS_REGION)_PREFIX)-bedrock2

TAGS ?= Project=$(STACK_NAME_PREFIX)

# Generic deployment and teardown targets
deploy-%:
	$(AWS_CMD) cloudformation deploy \
		--stack-name $(STACK_NAME_PREFIX)-$* \
		--tags $(TAGS) \
		--template-file templates/$*.yaml \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameter-overrides StackNamePrefix=$(STACK_NAME_PREFIX) DeployerArn=$(DEPLOYER_ARN) \
		$(EXTRA_ARGS)

delete-%:
	$(AWS_CMD) cloudformation delete-stack \
		--stack-name $(STACK_NAME_PREFIX)-$*

# Concrete deploy and delete targets for autocompletion
$(addprefix deploy-,$(basename $(notdir $(wildcard templates/*.yaml)))):
$(addprefix delete-,$(basename $(notdir $(wildcard templates/*.yaml)))):

AOSS_COLLECTION_ENDPOINT = $(shell $(AWS_CMD) cloudformation describe-stacks --stack-name $(STACK_NAME_PREFIX)-kb-infra --query 'Stacks[0].Outputs[?@.OutputKey==`CollectionEndpoint`].OutputValue' --output text)
VECTOR_INDEX_NAME = $(STACK_NAME_PREFIX)-kb-index
create-vector-index:
	awscurl --service aoss --region $(AWS_REGION) -X PUT $(AOSS_COLLECTION_ENDPOINT)/$(VECTOR_INDEX_NAME) --data @data/vector-index-config.json

AOSS_COLLECTION_ARN = $(shell $(AWS_CMD) cloudformation describe-stacks --stack-name $(STACK_NAME_PREFIX)-kb-infra --query 'Stacks[0].Outputs[?@.OutputKey==`CollectionArn`].OutputValue' --output text)
BEDROCK_KB_NAME = $(STACK_NAME_PREFIX)-kb
BEDROCK_ROLE_ARN = $(shell $(AWS_CMD) cloudformation describe-stacks --stack-name $(STACK_NAME_PREFIX)-kb-infra --query 'Stacks[0].Outputs[?@.OutputKey==`BedrockRoleArn`].OutputValue' --output text)
create-knowledge-base:
	sed \
		-e "s|BEDROCK_KB_NAME|$(BEDROCK_KB_NAME)|g" \
		-e "s|BEDROCK_ROLE_ARN|$(BEDROCK_ROLE_ARN)|g" \
		-e "s|AOSS_COLLECTION_ARN|$(AOSS_COLLECTION_ARN)|g" \
		-e "s|VECTOR_INDEX_NAME|$(VECTOR_INDEX_NAME)|g" \
		data/create-knowledge-base-input.json.template > data/create-knowledge-base-input.json
	aws bedrock-agent create-knowledge-base --cli-input-json file://data/create-knowledge-base-input.json

delete-knowledge-base:
	aws bedrock-agent delete-knowledge-base --knowledge-base-id $(BEDROCK_KB_ID)

BEDROCK_DS_NAME = $(STACK_NAME_PREFIX)-kb-ds
BEDROCK_KB_ID = $(shell $(AWS_CMD) bedrock-agent list-knowledge-bases --query 'knowledgeBaseSummaries[?@.name == `$(BEDROCK_KB_NAME)`].knowledgeBaseId' --output text)
BEDROCK_KB_INPUT_BUCKET_ARN = $(shell $(AWS_CMD) cloudformation describe-stacks --stack-name $(STACK_NAME_PREFIX)-kb-infra --query 'Stacks[0].Outputs[?@.OutputKey==`InputBucketArn`].OutputValue' --output text)
create-data-source:
	sed \
		-e "s|BEDROCK_KB_ID|$(BEDROCK_KB_ID)|g" \
		-e "s|BEDROCK_DS_NAME|$(BEDROCK_DS_NAME)|g" \
		-e "s|BEDROCK_KB_INPUT_BUCKET_ARN|$(BEDROCK_KB_INPUT_BUCKET_ARN)|g" \
		data/create-data-source-input.json.template > data/create-data-source-input.json

	aws bedrock-agent create-data-source --cli-input-json file://data/create-data-source-input.json

echo-%:
	@echo $($*)