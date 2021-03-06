#! /bin/bash

cd $(dirname $0)

IBMCLOUD=$(pwd)/Bluemix_CLI/bin/ibmcloud
CF=$HOME/.bluemix/.cf/cfcli/cf
#BLUE="\e[00;34m"
#RED="\e[00;31m"
#END="\e[0m"
BLUE=""
RED=""
END="==================================="

if [ ! -f "$IBMCLOUD" ]; then
    echo "${BLUE}download ibm-cloud-cli-release${END}"
    ver=$(curl -s https://github.com/IBM-Cloud/ibm-cloud-cli-release/releases/latest | grep -Po "(\d+\.){2}\d+")
    #ver=1.1.0
    wget -q -Oibm_cli.tgz https://clis.cloud.ibm.com/download/bluemix-cli/$ver/linux64
    if [ $? -eq 0 ]; then
        tar xzf ibm_cli.tgz
    else
        echo "${RED}download new version failed!${END}"
        exit 1
    fi
    rm -fv ibm_cli.tgz
fi

# set default env
IBM_MEMORY=${IBM_MEMORY:-"256M"}
V2_ID=${V2_ID:-"d007eab8-ac2a-4a7f-287a-f0d50ef08680"}
V2_PATH=${V2_PATH:-"path"}
ALTER_ID=${ALTER_ID:-"1"}
mkdir -p $IBM_APP_NAME

if [ ! -f "./config/trojan" ]; then
    echo "${BLUE}download trojan${END}"
    pushd ./config
    new_ver=$(curl -s https://github.com/trojan-gfw/trojan/releases/latest | grep -Po "(\d+\.){2}\d+")
    wget -q -Otrojan.tar.xz https://github.com/trojan-gfw/trojan/releases/download/v${new_ver}/trojan-${new_ver}-linux-amd64.tar.xz
    if [ $? -eq 0 ]; then
        tar xvf trojan.tar.xz trojan/trojan --strip-components 1
        chmod 700 trojan
    else
        echo "${RED}download new version failed!${END}"
        exit 1
    fi
    rm -fv trojan.tar.xz
    popd
fi

# cloudfoundry config
cp -rvf ./config/manifest.yml ./$IBM_APP_NAME/
sed "s/IBM_APP_NAME/${IBM_APP_NAME}/" ./$IBM_APP_NAME/manifest.yml -i
sed "s/IBM_MEMORY/${IBM_MEMORY}/" ./$IBM_APP_NAME/manifest.yml -i

# trojan config
cp -vf ./config/trojan ./$IBM_APP_NAME/$IBM_APP_NAME
{
    echo "#! /bin/bash"
    echo "wget https://raw.githubusercontent.com/$GITHUB_REPOSITORY/master/config/config.json"
    echo "wget https://raw.githubusercontent.com/$GITHUB_REPOSITORY/master/config/ngnix.conf"
    echo "sed 's/V2_ID/$V2_ID/' config.json -i"
    echo "sed 's/V2_PATH/$V2_PATH/' config.json -i"
    echo "sed 's/ALTER_ID/$ALTER_ID/' config.json -i"

} > ./$IBM_APP_NAME/d.sh
chmod +x ./$IBM_APP_NAME/d.sh

#cat ./$IBM_APP_NAME/d.sh
#exit 0

#echo "${BLUE}ibmcloud login${END}"
#$IBMCLOUD login -r us-south <<EOF
#$IBM_ACCOUNT
#$IBM_PASSWORD
#n
#EOF

#if [ -n "$RESOURSE_ID" ]; then
#    echo "${BLUE}ibmcloud set RESOURSE_ID${END}"
#    $IBMCLOUD target -g $RESOURSE_ID
#fi

if [ ! -f "$CF" ]; then
    echo "${BLUE}ibmcloud cf install${END}"
    $IBMCLOUD cf install
    #$IBMCLOUD target --cf-api 'https://api.us-south.cf.cloud.ibm.com'
fi
#$IBMCLOUD target --cf

echo "${BLUE}cf login${END}"
$CF login -a https://api.us-south.cf.cloud.ibm.com <<EOF
$IBM_ACCOUNT
$IBM_PASSWORD
EOF

cd ./$IBM_APP_NAME
#echo "${BLUE}ibmcloud cf push${END}"
#$IBMCLOUD cf push
echo "${BLUE}cf push${END}"
$CF push

if [ $? -ne 0 ]; then
    echo "${BLUE}print error${END}"
    $CF logs $IBM_APP_NAME --recent
    exit 1
fi
