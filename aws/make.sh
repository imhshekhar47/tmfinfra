#!/bin/bash
if [[ ! -f aws.env ]]; then
	echo "Error: AWS environment file is missing";
	echo "Please create environment file";
	echo "Example:"
	echo "export AWS_ACCESS_KEY_ID="
	echo "export AWS_SECRET_ACCESS_KEY="
	echo "export AWS_DEFAULT_REGION="
	echo "export AWS_CLI_FILE_ENCODING=UTF-8"
	echo "export KUBECONFIG=./.kube/config.yaml"
	echo "alias aws_info=aws sts get-caller-identity | jq -r '.Arn'"
	echo "alias aws_account=aws iam list-account-aliases | jq -r '.AccountAliases[0]'"
	exit 1;
fi

source aws.env --source-only

SCRIPT=$(basename ${0})

usage() {
	echo "make [info|amis|config|apply|clean]"
}

fatal() {
	echo "$*"
	exit 1;
}

show_info() {
	ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
	IAM_USERNAME=$(aws iam list-account-aliases | jq -r '.AccountAliases[0]')
	echo "Info"
	echo "----------------------------------------"
	echo "IAM_USERNAME: ${IAM_USERNAME}"
	echo "ACCOUNT_ID  : ${ACCOUNT_ID}"
	echo "----------------------------------------"
}

build_amis() {
	for hcl_file in `find ./amis/ -name *.hcl`; do
		echo "Build $(dirname ${hcl_file})"
		packer build "${hcl_file}"
	done
}

tf_configure() {
	[[ -d "./kube" ]] && rm -r "./kube"
	[[ -f "terraform.tfstate" ]] && rm terraform.tfstate
	terraform init \
		&& terraform plan
}

tf_apply() {
	terraform apply \
		&& terraform state list
}

tf_clean() {
	rm *.tfstate *.tfstate.backup
}

ACTION="$1"
case "${ACTION}" in
	info*)
		show_info
		;;
	amis*)
		build_amis $@
		;;
	config*)
		tf_configure $@
		;;
	apply*)
		tf_apply
		;;
	clean*)
		tf_clean
		;;
	*)
		usage
		fatal "Invalid argument $@"
		;;
esac 

exit $?;