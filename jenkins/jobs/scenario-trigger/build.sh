#!/bin/bash
# Copyright 2018 VMware, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Usage example: ./build.sh vic-engine-builds master vic_ vic-master-nightly

set -ex

ARTIFACT_BUCKET=$1
REPO_BRANCH=$2
BINARY_PREFIX=$3
JENKINS_JOB=$4
JENKINS_URL=https://vic-jenkins.eng.vmware.com/
JENKINS_USER=svc.vicuser
JENKINS_PASSWD='m!Q4Q94TZu1@sQze^@^'
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Get the latest build filename
if [ "${REPO_BRANCH}" == "master" ]; then
    GS_PATH="${ARTIFACT_BUCKET}"
else
    GS_PATH="${ARTIFACT_BUCKET}/${REPO_BRANCH}"
fi
FILE_NAME=$(gsutil ls -l "gs://${GS_PATH}/${BINARY_PREFIX}*" | grep -v TOTAL | sort -k2 -r | head -n1 | xargs | cut -d ' ' -f 3 | xargs basename)

CHECK_RELEASE_COUNT=3
# strip prefix and suffix from archive filename
case ${ARTIFACT_BUCKET} in
    vic-engine-builds)
        BUILD_NUM=${FILE_NAME#${BINARY_PREFIX}}
        BUILD_NUM=${BUILD_NUM%%.*}
        ;;
    "vic-product-ova-builds")
        BUILD_NUM=$(echo ${FILE_NAME} | awk -F '-' '{NF--;  print $NF }')
        ;;
    *)
        echo "Bucket ${ARTIFACT_BUCKET} is not supported."
        exit 1
        ;;
esac
echo "Trigger build ${BUILD_NUM}"

# Run test on vsphere 6.0, 6.5, 6.7 7.0 alternatively
DAY=`date +%u`
REM=$(( $DAY % $CHECK_RELEASE_COUNT ))
if [ ${REM} -eq 0 ]; then
# 67 release
#    export VC_BUILD_ID="ob-8217866"
#    export ESX_BUILD_ID="ob-8169922"
# 67U1 release on Oct.06 2018
#    export VC_BUILD_ID="ob-10244745"
#    export ESX_BUILD_ID="ob-10302608"
#    export VSPHERE_VERSION="6.7"
# 67U2 release on Apr.11 2019
#    export VC_BUILD_ID="ob-13010631"
#    export ESX_BUILD_ID="ob-13006603"
#    export VSPHERE_VERSION="6.7"
# 67U3 release on Aug.20 2019
    export VC_BUILD_ID="ob-14367737"
    export ESX_BUILD_ID="ob-14320388"
    export VSPHERE_VERSION="6.7"
elif [ ${REM} -eq 1 ]; then
#   65U2
#    export VC_BUILD_ID="ob-8307201"
#    export ESX_BUILD_ID="ob-8935087"
#    export VSPHERE_VERSION="6.5"
#   65U3
    export VC_BUILD_ID="ob-14020092"
    export ESX_BUILD_ID="ob-13932383"
    export VSPHERE_VERSION="6.5"
else
    # 7.0u1
    export VC_BUILD_ID="ob-16860138"
    export ESX_BUILD_ID="ob-16850804"
    export VSPHERE_VERSION="7.0"
fi
echo "VC build: ${VC_BUILD_ID}"
echo "ESX build: ${ESX_BUILD_ID}"
echo "vSPhere version: ${VSPHERE_VERSION}"

python "${SCRIPT_DIR}/jenkins_job_trigger.py" "${JENKINS_URL}" "${JENKINS_USER}" "${JENKINS_PASSWD}" "${VSPHERE_VERSION}" "${VC_BUILD_ID}" "${ESX_BUILD_ID}" "${BUILD_NUM}" "${JENKINS_JOB}"
