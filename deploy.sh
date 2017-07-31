#!/usr/bin/env bash

# set -x # for debug the script. remember -x is a global enviroment variable
set +x # or no set for no debug the script

echo
echo "*********************************************************"
echo "* BEGIN: deploy.sh"
echo "* version 1.0"
echo "* Autor: adlpzrmn"
echo "* First argument = $1"
echo "* Time: " `date`
echo "*********************************************************"

if [[ $1 == "local" ]]; then
    DEPLOY_ENVIROMENT="local";
    PATH_FROM_DEPLOY_ENV_CONF="conf_env/local"
    PATH_TO_DEPLOY="$HOME/_work/packet-terraform-dcos-calico-local";
elif [[ $1 == "int" ]]; then
    DEPLOY_ENVIROMENT="int";
    PATH_FROM_DEPLOY_ENV_CONF="conf_env/int";
    PATH_TO_DEPLOY="$HOME/_work/packet-terraform-dcos-calico-int";
elif [[ $1 == "test" ]]; then
    DEPLOY_ENVIROMENT="test";
    PATH_FROM_DEPLOY_ENV_CONF="conf_env/test";
    PATH_TO_DEPLOY="$HOME/_work/packet-terraform-dcos-calico-test"; 
elif [[ $1 == "prepro" ]]; then
    DEPLOY_ENVIROMENT="prepro";
    PATH_FROM_DEPLOY_ENV_CONF="conf_env/prepro";
    PATH_TO_DEPLOY="$HOME/_work/packet-terraform-dcos-calico-prepro";
elif [[ $1 == "pro" ]]; then
    DEPLOY_ENVIROMENT="pro";
    PATH_FROM_DEPLOY_ENV_CONF="conf_env/pro";
    PATH_TO_DEPLOY="$HOME/_work/packet-terraform-dcos-calico-pro";
else # Assume the first argument has value "dev"
    DEPLOY_ENVIROMENT="dev";
    PATH_FROM_DEPLOY_ENV_CONF="conf_env/dev";
    PATH_TO_DEPLOY="$HOME/_work/packet-terraform-dcos-calico-dev";
fi

FILES_TO_DEPLOY="dcos.tf make-files.sh output.tf vars.tf conf_dev $PATH_FROM_DEPLOY_ENV_CONF/*"
INITIAL_CWD=`pwd`

echo
echo "*********************************************************"
echo "* Environment:"
echo "* Deploy environment: DEPLOY_ENVIROMENT=$DEPLOY_ENVIROMENT"
echo "* Path to deploy: PATH_TO_DEPLOY=$PATH_TO_DEPLOY"
echo "* Path from deploy environment configuration: PATH_FROM_DEPLOY_ENV_CONF=$PATH_FROM_DEPLOY_ENV_CONF"
echo "* Files to deploy: FILES_TO_DEPLOY=$FILES_TO_DEPLOY"
echo "* Initial Current Work Directory: INITIAL_CWD=$INITIAL_CWD"
echo "*********************************************************"

#**************************************************************
echo
echo "*********************************************************"
echo "** ACTION: Copy files to deploy: $FILES_TO_DEPLOY into the path to deploy environment: $PATH_TO_DEPLOY"

rm $PATH_TO_DEPLOY/*

# cp -u $FILES_TO_DEPLOY $PATH_TO_DEPLOY # -u copy only modified files
cp $FILES_TO_DEPLOY $PATH_TO_DEPLOY

if [[ $? == 0 ]]; then
    echo "** SUCCESS: Copy files to deploy: $FILES_TO_DEPLOY into the path to deploy environment: $PATH_TO_DEPLOY";
else
    echo "** FAILURE: Copy files to deploy: $FILES_TO_DEPLOY into the path to deploy environment: $PATH_TO_DEPLOY";
fi

#**************************************************************
echo
echo "*********************************************************"
echo "** ACTION: Validate files to deployed";

cd $PATH_TO_DEPLOY

terraform validate

if [[ $? == 0 ]]; then
    echo "** SUCCESS: Validate files to deployed";
else
    echo "** FAILURE: Validate files to deployed. Verify the ouput of the validation";
fi

#**************************************************************
echo
echo "*********************************************************"
echo "** ACTION: Return to initial CWD";
cd $INITIAL_CWD

#**************************************************************
echo
echo "*********************************************************"
echo "* END: deploy.sh"
echo "* Time: " `date`
echo "*********************************************************"
echo

# terraform apply