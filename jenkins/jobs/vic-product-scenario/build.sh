#!/bin/bash
# Copyright 2018 VMware, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License
set -x

SCRIPT_DIR=$(dirname "$0")
WORKSPACE_DIR=$(cd $(dirname "$0")/../../../.. && pwd)

# 6.0u3
ESX_60_VERSION="ob-5050593"
VC_60_VERSION="ob-5112509" # the cloudvm build corresponding to the vpx build

# 6.5u2
#ESX_65_VERSION="ob-8935087"
#VC_65_VERSION="ob-8307201"

# 6.5u3
ESX_65_VERSION="ob-13932383"
VC_65_VERSION="ob-14020092"

# 6.7
#ESX_67_VERSION="ob-8169922"
#VC_67_VERSION="ob-8217866"
# 6.7U1
#ESX_67_VERSION="ob-10302608"
#VC_67_VERSION="ob-10244745"
#6.7U2
#ESX_67_VERSION="ob-13006603"
#VC_67_VERSION="ob-13010631"

# 6.7u3
ESX_67_VERSION="ob-14320388"
VC_67_VERSION="ob-14367737"

#7.0
#ESX_70_VERSION="ob-15843807"
#VC_70_VERSION="ob-15952498"

#7.0u1
#ESX_70_VERSION="ob-16850804"
#VC_70_VERSION="ob-16860138"

#7.0u2
ESX_70_VERSION="ob-17473468"
VC_70_VERSION="ob-17478525"

#DEFAULT_TESTCASES=("tests/manual-test-cases")
DEFAULT_TESTCASES=("tests/manual-test-cases/Group2-OVA-Features" "tests/manual-test-cases/Group5-Interoperability-Tests" "tests/manual-test-cases/Group6-OVA-TLS" "tests/manual-test-cases/Group7-Upgrade" "tests/manual-test-cases/Group8-Manual-Upgrade" "tests/manual-test-cases/Group9-VIC-UI")

DEFAULT_VIC_PRODUCT_BRANCH="master"
DEFAULT_VIC_PRODUCT_BUILD="*"
NIMBUS_LOCATION=${NIMBUS_LOCATION:-sc}
DEFAULT_PARALLEL_JOBS=4

echo "Target version: ${VSPHERE_VERSION}"
excludes=(--exclude skip)
case "$VSPHERE_VERSION" in
    "6.0")
        ESX_BUILD=${ESX_BUILD:-$ESX_60_VERSION}
        VC_BUILD=${VC_BUILD:-$VC_60_VERSION}
        DEFAULT_TESTCASES=("tests/manual-test-cases/Group2-OVA-Features" "tests/manual-test-cases/Group6-OVA-TLS" "tests/manual-test-cases/Group7-Upgrade" "tests/manual-test-cases/Group8-Manual-Upgrade" "tests/manual-test-cases/Group9-VIC-UI")
        ;;
    "6.5")
        ESX_BUILD=${ESX_BUILD:-$ESX_65_VERSION}
        VC_BUILD=${VC_BUILD:-$VC_65_VERSION}
        ;;
    "6.7")
        ESX_BUILD=${ESX_BUILD:-$ESX_67_VERSION}
        VC_BUILD=${VC_BUILD:-$VC_67_VERSION}
        ;;
    "7.0")
        excludes+=(--exclude vsphere70-not-support)
        ESX_BUILD=${ESX_BUILD:-$ESX_70_VERSION}
        VC_BUILD=${VC_BUILD:-$VC_70_VERSION}
        ;;
esac

testcases=("${@:-${DEFAULT_TESTCASES[@]}}")
${ARTIFACT_PREFIX:="vic-*"}
${GCS_BUCKET:="vic-product-ova-builds"}

VIC_PRODUCT_BRANCH=${VIC_PRODUCT_BRANCH:-${DEFAULT_VIC_PRODUCT_BRANCH}}
VIC_PRODUCT_BUILD=${VIC_PRODUCT_BUILD:-${DEFAULT_VIC_PRODUCT_BUILD}}
if [ "${VIC_PRODUCT_BRANCH}" == "${DEFAULT_VIC_PRODUCT_BRANCH}" ]; then
    GS_PATH="${GCS_BUCKET}"
else
    GS_PATH="${GCS_BUCKET}/${VIC_PRODUCT_BRANCH}"
fi
input=$(gsutil ls -l "gs://${GS_PATH}/${ARTIFACT_PREFIX}-${VIC_PRODUCT_BUILD}-*" | grep -v TOTAL | sort -k2 -r | head -n1 | xargs | cut -d ' ' -f 3 | xargs basename)
constructed_url="https://storage.googleapis.com/${GS_PATH}/${input}"
ARTIFACT_URL="${ARTIFACT_URL:-${constructed_url}}"
input=$(basename "${ARTIFACT_URL}")

pushd ${WORKSPACE_DIR}/vic-product
    echo "Downloading VIC Product OVA build $input... from ${ARTIFACT_URL}"
    n=0 && rm -f "${input}"
    until [[ $n -ge 5 ]]; do
        echo "Retry.. $n"
        echo "Downloading gcp file ${input} from ${ARTIFACT_URL}"
        wget --unlink -nv -O "${input}" "${ARTIFACT_URL}" && break;
        # clean up any residual file from failed download
        rm -f "${input}"
        ((n++))
        sleep 10;
    done

    if [[ ! -f $input ]]; then
        echo "VIC Product OVA download failed"
        exit 1
    fi
    echo "VIC Product OVA download complete..."

#    users=(${NIMBUS_PERSONAL_USER})
#    PARALLEL_JOBS=${#users[@]}
#    if [[ $PARALLEL_JOBS -ne 1 ]];then
#        cat > valueset.dat <<ENVS
#[USER=0]
#NIMBUS_PERSONAL_USER=notused
#ENVS
#        for (( i = 0 ; i < ${#users[@]} ; i++ ))
#        do
#            idx=$(($i+1))
#            cat >> valueset.dat <<ENVS
#[USER=$idx]
#NIMBUS_PERSONAL_USER=${users[$i]}
#ENVS
#done
#    
#    pabot --verbose --processes "${PARALLEL_JOBS}" --pabotlib --resourcefile valueset.dat --listener tests/resources/new_listener.py -d report "${excludes[@]}" --variable ESX_VERSION:"${ESX_BUILD}" --variable VC_VERSION:"${VC_BUILD}" --variable NIMBUS_LOCATION:"${NIMBUS_LOCATION}" "${testcases[@]}"
    PARALLEL_JOBS=${PARALLEL_JOBS:-${DEFAULT_PARALLEL_JOBS}}
    pabot --verbose --processes "${PARALLEL_JOBS}" -d report "${excludes[@]}" --variable ESX_VERSION:"${ESX_BUILD}" --variable VC_VERSION:"${VC_BUILD}" --variable NIMBUS_LOCATION:"${NIMBUS_LOCATION}" "${testcases[@]}"
    cat report/pabot_results/*/stdout.txt | grep -E '::|\.\.\.' | grep -E 'PASS|FAIL' > console.log

    # Pretty up the email results
    sed -i -e 's/^/<br>/g' console.log
    sed -i -e 's|PASS|<font color="green">PASS</font>|g' console.log
    sed -i -e 's|FAIL|<font color="red">FAIL</font>|g' console.log
    cp -R test-screenshots report 2>/dev/null || echo "no test-screenshots directory"
    mv *.tar.gz report 2>/dev/null || echo "no appliance log to collect"

    upload_logs=0
    # archive the logs
# disable post log to google cloud, since jenkins can show those appliance bundle log now
#    logarchive="vic-product-scenarios_${BUILD_ID}_${BUILD_TIMESTAMP}.zip"
#    /usr/bin/zip -9 -r "${logarchive}" report
#    if [ $? -eq 0 ]; then
#        upload_logs=1
#    fi
popd
if [ $upload_logs -eq 1 ]; then
   ${SCRIPT_DIR}/upload-logs.sh ./vic-product/${logarchive} vic-product-logs/test
fi
