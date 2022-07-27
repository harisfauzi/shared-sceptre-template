#!/bin/bash

set -eEu -o pipefail +x
AWS_ACCOUNT=""
LONG_AWS_PROFILE=""
SHORT_AWS_PROFILE=""
ARG_ARRAY=()
SCRIPT_ACTION="deploy"
CFN_CONFIG=""
DRY_RUN="false"
PARAMS=""

get_short_term_credentials() {
    AWS_ACCESS_KEY=$(grep -A6 "\[${SHORT_AWS_PROFILE}\]" ~/.aws/credentials | grep aws_access_key_id | awk '{print $NF}')
    AWS_SECRET_KEY=$(grep -A6 "\[${SHORT_AWS_PROFILE}\]" ~/.aws/credentials | grep aws_secret_access_key | awk '{print $NF}')
    AWS_SECURITY_TOKEN=$(grep -A6 "\[${SHORT_AWS_PROFILE}\]" ~/.aws/credentials | grep aws_session_token | awk '{print $NF}')
    AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
    AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
    AWS_SESSION_TOKEN=$AWS_SECURITY_TOKEN
    export AWS_ACCESS_KEY AWS_SECRET_KEY AWS_SECURITY_TOKEN AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
}

get_long_term_credentials() {
    AWS_ACCESS_KEY=$(grep -A2 "\[${LONG_AWS_PROFILE}\]" ~/.aws/credentials | grep aws_access_key_id | awk '{print $NF}')
    AWS_SECRET_KEY=$(grep -A2 "\[${LONG_AWS_PROFILE}\]" ~/.aws/credentials | grep aws_secret_access_key | awk '{print $NF}')
    AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
    AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
    export AWS_ACCESS_KEY AWS_SECRET_KEY AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
}

assume_role() {
    local aws_account_id=$(aws ssm get-parameter --name /target/account/${AWS_ACCOUNT} --query "Parameter.Value" --output text)
    local aws_iam_role=$(aws ssm get-parameter --name /target/iam_role/${AWS_ACCOUNT} --query "Parameter.Value" --output text)
    echo "Using $aws_account_id AWS Account ID"

    local identity_session=$(aws sts get-caller-identity | jq -r '.Arn' | awk -F'/' '{print $NF}')
    local role_session_name="${identity_session}@$(date +%s)"
    local LOCAL_PROFILE=()
    if [ "${LONG_AWS_PROFILE}" != "" ]; then
      LOCAL_PROFILE+=("--profile")
      LOCAL_PROFILE+=("${LONG_AWS_PROFILE}")
    fi
    ASSUMED_CREDENTIALS=$(aws sts assume-role ${LOCAL_PROFILE[@]} --region us-west-1 \
        --role-arn "${aws_iam_role}" \
        --role-session-name "${role_session_name}")

    # Ansible
    AWS_ACCESS_KEY=$(echo ${ASSUMED_CREDENTIALS} | jq -r '.Credentials.AccessKeyId')
    AWS_SECRET_KEY=$(echo ${ASSUMED_CREDENTIALS} | jq -r '.Credentials.SecretAccessKey')
    AWS_SECURITY_TOKEN=$(echo ${ASSUMED_CREDENTIALS} | jq -r '.Credentials.SessionToken')
    export AWS_ACCESS_KEY AWS_SECRET_KEY AWS_SECURITY_TOKEN
    # AWS CLI
    AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
    AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
    AWS_SESSION_TOKEN=$AWS_SECURITY_TOKEN
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    echo "Assumed AWS_ACCESS_KEY is $AWS_ACCESS_KEY"
}

launch() {
    local SCRIPT_ACTION=$1
    local CFN_CONFIG=$2
    cd sceptre/
    local DOCKER_IMAGE=harisfauzi/hf-sceptre:3.1.0-03

    local SOURCE_REPO_URL='git@github.com:harisfauzi/shared-sceptre-template.git'  # $(git remote get-url origin | cut -d':' -f2)
    local SOURCE_REPO_BRANCH=main  # $(git branch| grep -e '^*' | awk '{print $2}')
    local dir_prefix=""
    if [ "${AWS_ACCOUNT}" != "" ]; then
      dir_prefix="${AWS_ACCOUNT}/"
    fi

    if [ "${SCRIPT_ACTION}" == "deploy" ]; then
        ACTION="launch -y"
    elif [ "${SCRIPT_ACTION}" == "destroy" ]; then
        ACTION="delete -y"
    elif [ "${SCRIPT_ACTION}" == "generate" ]; then
        ACTION="generate"
    else
      echo "Invalid action. You need to define action as"
      echo "$0 -n <action>"
      echo "Where valid actions are choice of deploy, destroy, generate."
    fi

    if [ "${DRY_RUN}" == "" -o "${DRY_RUN}" == "false" ]; then
        echo "[Calling:]"
        echo "docker run \
          --env AWS_ACCESS_KEY \
          --env AWS_ACCESS_KEY_ID \
          --env AWS_DEFAULT_REGION \
          --env AWS_SECRET_ACCESS_KEY \
          --env AWS_SECRET_KEY \
          --env AWS_SECURITY_TOKEN \
          --env AWS_SESSION_TOKEN \
          --env SOURCE_REPO_URL=\"${SOURCE_REPO_URL}\" \
          --env SOURCE_REPO_BRANCH=\"${SOURCE_REPO_BRANCH}\" \
          --rm \
          -v $(pwd):/workspace \
          -v /etc/passwd:/etc/passwd:ro \
          -v /etc/group:/etc/group:ro \
          -u $(id --user) \
          -w /workspace \
          ${DOCKER_IMAGE} \
          --var-file /workspace/vars/main.yaml "${ARG_ARRAY[@]}" \
          ${ACTION} ${dir_prefix}${CFN_CONFIG}"
        docker run \
          --env AWS_ACCESS_KEY \
          --env AWS_ACCESS_KEY_ID \
          --env AWS_DEFAULT_REGION \
          --env AWS_SECRET_ACCESS_KEY \
          --env AWS_SECRET_KEY \
          --env AWS_SECURITY_TOKEN \
          --env AWS_SESSION_TOKEN \
          --env SOURCE_REPO_URL="${SOURCE_REPO_URL}" \
          --env SOURCE_REPO_BRANCH="${SOURCE_REPO_BRANCH}" \
          --rm \
          -v $(pwd):/workspace \
          -v /etc/passwd:/etc/passwd:ro \
          -v /etc/group:/etc/group:ro \
          -u $(id --user) \
          -w /workspace \
          ${DOCKER_IMAGE} \
          --var-file /workspace/vars/main.yaml "${ARG_ARRAY[@]}" \
          ${ACTION} ${dir_prefix}${CFN_CONFIG}
    fi
    EXIT_STATUS=$?
    cd ../
    exit ${EXIT_STATUS}

}

parse_arguments() {
    while (( "$#" )); do
      case "$1" in
        -a|--account)
          AWS_ACCOUNT=$2
          shift 2
          ;;
        -l|--long-term-profile)
          LONG_AWS_PROFILE=$2
          shift 2
          ;;
        -s|--short-term-profile)
          SHORT_AWS_PROFILE=$2
          shift 2
          ;;
        -e|--extra-vars)
          ARG_ARRAY+=("--var" "${2}")
          shift 2
          ;;
        -f|--var-file)
          ARG_ARRAY+=("--var-file" "/workspace/vars/${2}")
          shift 2
          ;;
        -n|--action)
          SCRIPT_ACTION=$2
          shift 2
          ;;
        -i|--item)
          CFN_CONFIG=$2
          shift 2
          ;;
        -d|--dry-run)
          DRY_RUN=$2
          shift 2
          ;;
        --) # end argument parsing
          shift
          break
          ;;
        -*|--*=) # unsupported flags
          echo "Error: Unsupported flag $1" >&2
          exit 1
          ;;
        *) # preserve positional arguments
          PARAMS="$PARAMS $1"
          shift
          ;;
      esac
    done
    # set positional arguments in their proper place
    eval set -- "$PARAMS"
}

get_template() {
  GIT_BRANCH=main
  git clone -b "${GIT_BRANCH}" --depth 1 https://github.com/harisfauzi/shared-sceptre-template.git shared-sceptre-template
  local CURRENT_DIR=$(pwd)
  (cd "${CURRENT_DIR}/shared-sceptre-template/templates"; tar cf - .) | (cd "${CURRENT_DIR}/sceptre/templates"; tar xf -)
  rm -rf shared-sceptre-template
}

main() {

    # SWITCH_ACCOUNT=1
    parse_arguments $@
    if [ "$AWS_ACCOUNT" != "" ]; then
        # Call assume_role to switch AWS account
        assume_role
    elif [ "$SHORT_AWS_PROFILE" != "" ]; then
        get_short_term_credentials
    elif [ "$LONG_AWS_PROFILE" != "" ]; then
        get_long_term_credentials
    fi

    get_template
    launch "${SCRIPT_ACTION}" "${CFN_CONFIG}"

}

main "$@"
