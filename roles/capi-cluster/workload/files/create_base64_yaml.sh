#!/bin/bash
# Copyright 2019 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# 	http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

CAPO_SCRIPT=create_base64_yaml.sh
while test $# -gt 0; do
        case "$1" in
          -h|--help)
            echo "${CAPO_SCRIPT} - sources env vars for clusterctl init from an OpenStack clouds.yaml file"
            echo " "
            echo "source ${CAPO_SCRIPT} [options] <path/to/clouds.yaml> <cloud>"
            echo " "
            echo "options:"
            echo "-h, --help                show brief help"
            exit 0
            ;;
          *)
            break
            ;;
        esac
done

# Check if clouds.yaml file provided
if [[ -n "${1-}" ]] && [[ $1 != -* ]] && [[ $1 != --* ]];then
  CAPO_CLOUDS_PATH="$1"
else
  echo "Error: No clouds.yaml provided"
  echo "You must provide a valid clouds.yaml script to generate a cloud.conf"
  echo ""
  exit 1
fi

# Check if os cloud is provided
if [[ -n "${2-}" ]] && [[ $2 != -* ]] && [[ $2 != --* ]]; then
  export CAPO_CLOUD=$2
else
  echo "Error: No cloud specified"
  echo "You must specify which cloud you want to use."
  echo ""
  exit 1
fi

CAPO_YQ_TYPE=$(file "$(which yq)")
if [[ ${CAPO_YQ_TYPE} == *"Python script"* ]]; then
  echo "Wrong version of 'yq' installed, please install the one from https://github.com/mikefarah/yq"
  echo ""
  exit 1
fi

CAPO_CLOUDS_PATH=${CAPO_CLOUDS_PATH:-""}
CAPO_OPENSTACK_CLOUD_YAML_CONTENT=$(cat "${CAPO_CLOUDS_PATH}")

CAPO_YQ_VERSION=$(yq -V)
yqNavigating(){
        if [[ ${CAPO_YQ_VERSION} == *"version 1"* || ${CAPO_YQ_VERSION} == *"version 2"* || ${CAPO_YQ_VERSION} == *"version 3"* ]]; then
                yq r $1 $2
        else
                yq e .$2 $1
        fi
}

b64encode(){
  # Check if wrap is supported. Otherwise, break is supported.
  if echo | base64 --wrap=0 &> /dev/null; then
    base64 --wrap=0 $1
  else
    base64 --break=0 $1
  fi
}

# Just blindly parse the cloud.yaml here, overwriting old vars.
CAPO_AUTH_URL=$(echo "$CAPO_OPENSTACK_CLOUD_YAML_CONTENT" | yqNavigating - clouds.${CAPO_CLOUD}.auth.auth_url)
CAPO_USERNAME=$(echo "$CAPO_OPENSTACK_CLOUD_YAML_CONTENT" | yqNavigating - clouds.${CAPO_CLOUD}.auth.username)
CAPO_PASSWORD=$(echo "$CAPO_OPENSTACK_CLOUD_YAML_CONTENT" | yqNavigating - clouds.${CAPO_CLOUD}.auth.password)
if [[ "$CAPO_PASSWORD" = "" || "$CAPO_PASSWORD" = "null" ]]; then
  CAPO_PASSWORD="${OS_PASSWORD}"
fi
CAPO_REGION=$(echo "$CAPO_OPENSTACK_CLOUD_YAML_CONTENT" | yqNavigating - clouds.${CAPO_CLOUD}.region_name)
CAPO_PROJECT_ID=$(echo "$CAPO_OPENSTACK_CLOUD_YAML_CONTENT" | yqNavigating - clouds.${CAPO_CLOUD}.auth.project_id)
CAPO_PROJECT_NAME=$(echo "$CAPO_OPENSTACK_CLOUD_YAML_CONTENT" | yqNavigating - clouds.${CAPO_CLOUD}.auth.project_name)
CAPO_DOMAIN_NAME=$(echo "$CAPO_OPENSTACK_CLOUD_YAML_CONTENT" | yqNavigating - clouds.${CAPO_CLOUD}.auth.user_domain_name)
CAPO_APPLICATION_CREDENTIAL_NAME=$(echo "$CAPO_OPENSTACK_CLOUD_YAML_CONTENT" | yqNavigating - clouds.${CAPO_CLOUD}.auth.application_credential_name)
CAPO_APPLICATION_CREDENTIAL_ID=$(echo "$CAPO_OPENSTACK_CLOUD_YAML_CONTENT" | yqNavigating - clouds.${CAPO_CLOUD}.auth.application_credential_id)
CAPO_APPLICATION_CREDENTIAL_SECRET=$(echo "$CAPO_OPENSTACK_CLOUD_YAML_CONTENT" | yqNavigating - clouds.${CAPO_CLOUD}.auth.application_credential_secret)
if [[ "$CAPO_DOMAIN_NAME" = "" || "$CAPO_DOMAIN_NAME" = "null" ]]; then
  CAPO_DOMAIN_NAME=$(echo "$CAPO_OPENSTACK_CLOUD_YAML_CONTENT" | yqNavigating - clouds.${CAPO_CLOUD}.auth.domain_name)
fi
CAPO_DOMAIN_ID=$(echo "$CAPO_OPENSTACK_CLOUD_YAML_CONTENT" | yqNavigating - clouds.${CAPO_CLOUD}.auth.user_domain_id)
if [[ "$CAPO_DOMAIN_ID" = "" || "$CAPO_DOMAIN_ID" = "null" ]]; then
  CAPO_DOMAIN_ID=$(echo "$CAPO_OPENSTACK_CLOUD_YAML_CONTENT" | yqNavigating - clouds.${CAPO_CLOUD}.auth.domain_id)
fi
CAPO_CACERT_ORIGINAL=$(echo "$CAPO_OPENSTACK_CLOUD_YAML_CONTENT" | yqNavigating - clouds.${CAPO_CLOUD}.cacert)

# Build OPENSTACK_CLOUD_YAML_B64
if [[ ${CAPO_YQ_VERSION} == *"version 1"* || ${CAPO_YQ_VERSION} == *"version 2"* || ${CAPO_YQ_VERSION} == *"version 3"* ]]; then
    if [[ "$CAPO_PASSWORD" = "" || "$CAPO_PASSWORD" = "null" ]]; then
        CAPO_OPENSTACK_CLOUD_YAML_SELECTED_CLOUD_B64=$(echo "${CAPO_OPENSTACK_CLOUD_YAML_CONTENT}" | yq r - clouds.${CAPO_CLOUD} | yq p - clouds.${CAPO_CLOUD} | b64encode)
    else
        CAPO_OPENSTACK_CLOUD_YAML_SELECTED_CLOUD_B64=$(echo "${CAPO_OPENSTACK_CLOUD_YAML_CONTENT}" | yq r - clouds.${CAPO_CLOUD} | yq w - auth.password ${CAPO_PASSWORD} | yq p - clouds.${CAPO_CLOUD} | b64encode)
    fi
else
    if [[ "$CAPO_PASSWORD" = "" || "$CAPO_PASSWORD" = "null" ]]; then
        CAPO_OPENSTACK_CLOUD_YAML_SELECTED_CLOUD_B64=$(echo "${CAPO_OPENSTACK_CLOUD_YAML_CONTENT}" | yq e .clouds.${CAPO_CLOUD} - | yq e '{"clouds": {"'${CAPO_CLOUD}'": . }}' - | b64encode)
    else
        CAPO_OPENSTACK_CLOUD_YAML_SELECTED_CLOUD_B64=$(echo "${CAPO_OPENSTACK_CLOUD_YAML_CONTENT}" | yq e .clouds.${CAPO_CLOUD} - | PASSWORD=${CAPO_PASSWORD} yq e '.auth.password = env(PASSWORD)' - | yq e '{"clouds": {"'${CAPO_CLOUD}'": . }}' - | b64encode)
    fi
fi
echo ${CAPO_OPENSTACK_CLOUD_YAML_SELECTED_CLOUD_B64}
