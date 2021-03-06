#!/bin/bash --norc
# (c) Copyright 2014 Hewlett-Packard Development Company, L.P.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# This script is a start point to build the Maestro box
# 
# Objectives:
# - Use hpcloud CDK environment
# - request hpcloud to create an empty server - ubuntu 12.04
# - send out user_data + metadata to make Maestro, with cloudinit
# - save the image snapshot to hpcloud
# - remove the Maestro built.
# 
# The script can be used by any jenkins build like system.
# We can start it from any dev system
# The dev/build system needs to have an hpcloud environment configured. 
# The vagrant orchestrator may be used to start this script. But any system running hpcloud tools is ok

# TODO: Make this script generic to build any BOX images. Currently it is building only Maestro
# TODO: Test existence of 'cloud-init boot finished' in the final_message, if configured in yaml setup.
#
# ChL: Added Build configuration load.

BUILD_CONFIG=bld
CONFIG_PATH=. # By default search for configuration files on the current directory

# Those data have to be configured in a build configuration file
#FORJ_BASE_IMG=
#FORJ_FLAVOR=

BUILD_PREFIX=bld-maestro-
BUILD_SUFFIX=.forj.io
BUILD_IMAGE_SUFFIX=built

GITBRANCH=master

APPPATH="."
BIN_PATH=$(cd $(dirname $0); pwd)
BUILD_SCRIPT=$BIN_PATH/$(basename $0)

BOOTHOOK=$BIN_PATH/build-tools/boothook.sh

MIME_SCRIPT=$BIN_PATH/build-tools/write-mime-multipart.py

TEST_BOX_SCRIPT="$(cd ../tools/bin/; pwd)/test-box.sh"

declare -A META
declare -A TEST_BOX

function usage
{
 if [ "$1" != "" ]
 then
    Warning "$1"
 fi
 echo "$0 --build_ID <BuildID> --box-name <BoxName> [--debug-box] [--test-box=<LocalrepoPath>] [--gitBranch <branch>/--gitBranchCur] [[--build-conf-dir <confdir>] --build-config <config>] [--gitRepo <RepoLink>] | -h
Script to build a Box identified as <BoxName>. You can create an image or simply that box to test it (--debug-box).
It uses 'hpcloud' cli. You may need to install it, before.

The build configuration identified as <Config> will define where this box/image will be created. By default, it is fixed to 'master'.
You can change it with option --gitBranch or --gitBranchCur if your configuration file is tracked by a git repository.

Using --build-config [1m<Config>[0m(with or without --build-conf-dir) will load information about:
- BUILD_ID                : Optionally force to use a build ID.
- APPPATH                 : Path to bootstrap files to use.

HPCloud services to configure:
- FORJ_HPC_TENANTID       : HPCloud Project tenant ID used.
- FORJ_HPC_COMPUTE        : HPCloud compute service to use.
- FORJ_HPC_NETWORKING     : HPCloud networking service to use.
- FORJ_HPC_CDN            : HPCloud CDN service to use.
- FORJ_HPC_OBJECT_STORAGE : HPCloud Object storage service to use.
- FORJ_HPC_BLOCK_STORAGE  : HPCloud Block storage service to use.
- FORJ_HPC_DNS            : HPCloud Domain name service to use.
- FORJ_HPC_LOAD_BALANCER  : HPCloud Load balancer service to use.
- FORJ_HPC_MONITORING     : HPCloud Monitoring service to use.
- FORJ_HPC_DB             : HPCloud Mysql service to use.
- FORJ_HPC_REPORTING      : HPCloud Reporting service to use.

Boot data needed:
- FORJ_HPC_NET or FORJ_HPC_NETID : HPCloud network name or network ID to use for boot.
- FORJ_BASE_IMG                  : HPCloud image ID to use for boot.
- FORJ_FLAVOR                    : HPCloud flavor ID to use for boot.
- FORJ_SECURITY_GROUP            : HPCloud security group to use. By default, it uses 'default'. 
- FORJ_KEYPAIR                   : HPCloud keypair to use. By default, it uses 'nova' as the name of the keypair.
- FORJ_HPC_NOVA_KEYPUB           : defines the public key file to import if the keypait(FORJ_KEYPAIR) is inexistent in HPCloud.
- BOOTSTRAP_DIR                  : Superseed default <BoxName> bootscripts. See Box bootstrap section for details.
                           

It will load this data from <confdir or .>/<BoxName>.[1m<Config>[0m.env file

Depending on the <config> data, you can build your box/image to different tenantID. one tenant for DEV, one tenant for PRO, etc...

To build your image, you need to be in the directory which have your <BoxName> as a sub directory. 

How your box is built?
======================
Your box is built is 2 big steps:
1. user_data Box bootstrap
2. local box bootstrap (defined in your repository/packages/files...)

user_data Box bootstrap is build by build.sh, sent as user_data during the boot call (to create your box on the cloud). 
As soon as the user_data, maestro user_data boot sequence will call an init.sh which will start the second step.

user_data Box bootstrap:
========================

build.sh will create a user_data to boot your box with the cloudinit feature as wanted.
To build it, build.sh will:
1. Include 'boothook.sh'
   Used to configure your hostname and workaround meta.js missing file. By default 'boothook.sh' is located in build/bin/build-tools/. You can change it with [1m--bootstrap[0m. See 'user-data bootstrap options' section for details.
2. check if <BoxName>/cloudconfig.yaml exist and add it.
3. build a 'boot box' shell script sequence from <BoxName/bootstrap/{#}-*.sh. 
   <BOOTSTRAP_DIR> environment variable will be merged with the default bootstrap dir. The merged files list are sorted by there name. if build found the same file name from all bootstrap directories, build.sh will include <BoxName>/bootstrap, then your BOOTSTRAP_DIR list.
   Also, you can add single extra steps, with [1m--extra-bs-step[0m. See 'user-data bootstrap options' section for details.

Then build.sh will create a mime file which will be sent to the box with user-data feature executed by cloudinit at box build boot time sequence.


Options details:
================
--build_ID <BuildID>           : identify a new build ID to create. Can be set in your build configuration.
--box-name <BoxName>           : Defines the name of the box or box image to build.

--gitBranch <branch>           : The build will extract from git branch name. It sets the configuration build <config> to the branch name <branch>.
--gitBranchCur                 : The build will use the default branch current set in your git repo. It sets the configuration build <config> to the current git branch.

--build-conf-dir <confdir>     : Defines the build configuration directory to load the build configuration file. You can set FORJ_BLD_CONF_DIR. By default, it will look in your current directory.
--build-config <config>        : The build config file to load <confdir>/<BoxName>.<Config>.env. By default, uses 'master' as Config.

--test-box                     : Create test-box meta from the repository path provided. 
                                 The remote server should interpret 'test-box' to wait for your local repository to be sent out to the box. 
                                 build.sh will try to discover which repository the box is requesting to send out your repository branch to the remote box, automatically, if test-box is in your PATH.
--debug-box                    : Use this option to create the server, and debug it. No image will be created. The server will stay alive at the end of the build process.
--gitRepo <RepoLink>           : The box built will use a different git repository sent out to <user_data>. This repository needs to be read only. No keys are sent.
--meta <meta>                  : Add a metadata. have to be Var=Value. You can use --meta several times in the command line. 
                                 On the configuration file, use META[<var>]='Var=Value' to force it.
-h                             : This help

user-data bootstrap options:
============================
--boothook <boothookFile>      : Optionnal. By default, boothook file used is build/bin/build-tools/boothook.sh. Use this option to set another one.
--extra-bs-step <[Order:]File> : Add an extra user_data bootstrap step. This file in a specific 'Order' will be concatenated to the 'boot box' mime sequence, like BOOTSTRAP_DIR.

By default, the config name is 'master'. But <Config> can be set to the name of the branch thanks to --gitBranch, --gitBranchCur or from --build-config

Detected configuration ready to use with --build-config from '$CONFIG_PATH': "
 ls $CONFIG_PATH/*.env 2>/dev/null | sed 's/\.env$//g'
 if [ "$1" != "" ]
 then
    echo "Nothing."
    Exit 1
 fi
 Exit 0
}


# ------------------------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------------------------

# Load build.d files

for INC_FILE in $BIN_PATH/build.d/*.d.sh
do
  source $INC_FILE
done

# Checking build options

if [ $# -eq 0 ]
then
   usage
fi

OPTS=$(getopt -o h -l setBranch:,box-name:,build-conf-dir:,debug-box,build_ID:,gitBranch:,gitBranchCur,gitRepo:,build-config:,gitLink:,debug,no-debug,meta:,meta-data:,boothook:,extra-bs-step:,test-box: -- "$@" )
if [ $? != 0 ]
then
    usage "Invalid options"
fi
eval set -- "$OPTS"

GIT_REPO=review:forj-oss/maestro

 
while true ; do
    case "$1" in
        -h) 
            usage;;
        --no-debug)
            set +x
            shift;;
        --debug)
            set -x
            shift;;
        --debug-box)
            DEBUG=True;
            shift;;
        --build_ID) 
            BUILD_ID="$(echo "$2" | awk '{ print $1}')"
            Info "Preparing to make $BUILD_ID"
            shift;shift;;
        --gitBranch)
            BRANCH="$(echo "$2" | awk '{ print $1}')"
            GITBRANCH="$(git branch --list $BRANCH)"
            if [ "$GITBRANCH" = "" ]
            then
               Error 1 "Branch '$BRANCH' does not exist. Use 'git branch' to find the appropriate branch name."
            fi
            if [ "$(echo $GITBRANCH | cut -c 1)" != "*" ]
            then
               Warning "Branch '$BRANCH' is not the default one"
            fi
            GITBRANCH="$BRANCH"
            shift;shift;; 
        --setBranch)
            GITBRANCH="$(echo "$2" | awk '{ print $1}')"
            shift; shift ;;
        --gitBranchCur)
            GITBRANCH="$(git branch | grep -e '^\*')"
            if [ "$GITBRANCH" = "" ]
            then
               Error 1 "Branch '$BRANCH' does not exist. Use 'git branch' to find the appropriate branch name."
            fi
            shift;;
        --build-conf-dir)
            CONFIG_PATH="$(echo "$2" | awk '{ print $1}')"
            if [ ! -d "$CONFIG_PATH" ]
            then
               Error 1 "'$CONFIG_PATH' is not a valid path for option '--build-conf-dir'. Please check."
            fi
            shift;shift;; 
        --box-name)
            APP_NAME="$(echo "$2" | awk '{ print $1}')"
            shift;shift;; 
        --build-config)
            BUILD_CONFIG="$(echo "$2" | awk '{ print $1}')"
            shift;shift;; 
        --gitRepo|--gitLink)
            GIT_REPO="$(echo "$2" | awk '{ print $1}')"
            Warning "Your git repository '$2' currently can not be tested by this script. Hope you checked it before building the box."
            shift;shift;; 
        "--test-box")
            if [ ! -d "$2" ]
            then
               Error 1 "$2 is not an accessible repository directory. Please check"
            fi
            cd "$2"
            git rev-parse --show-toplevel 2>/dev/null 1>&2
            if [ $? -ne 0 ]
            then
               Error 1 "'$1' is not a valid repository. Please check and retry."
            fi
            REPO_TO_ADD="$(LANG= git remote show origin -n | awk '$1 ~ /Fetch/ { print $3 }'| sed 's!^.*/\([a-z]*\)\(.git\)\?!\1!g')"
            if [ "$REPO_TO_ADD" = "" ]
            then
               Error 1 "Unable to identify the repository name from git remote 'origin'. Please check '$2'"
            fi
            if [ "${META['test-box']}" = "" ]
            then
                META['test-box']="test-box=$REPO_TO_ADD;testing-$(id -un)"
            else
                META['test-box']="${META['test-box']}|$REPO_TO_ADD;testing-$(id -un)"
            fi
            TEST_BOX[$REPO_TO_ADD]=$(pwd)
            Info "Test-box: Repository '$REPO_TO_ADD' added to the list."
            cd - >/dev/null
            shift;shift;;
        --meta)
            META_NAME="$(echo "$2" | awk -F= '{print $1}' | awk '{ print $1}')"
            META_VAL="$( echo "$2" | awk -F= '{print $2}' | awk '{ print $1}')"
            META[$META_NAME]="$META_NAME=$META_VAL"
            echo "Meta set : $META_NAME"
            unset META_NAME META_VAL
            shift;shift;; 
        --meta-data)
            load-meta "$2"
            shift;shift;;
        --boothook)
            if [ ! -f "$2" ]
            then
               Error 1 "'$2' is not a valid boothook file."
            fi   
            BOOTHOOK="$(pwd)/$2"
            shift;shift;;
        --extra-bs-step)
            BS_STEP="$2"
            BS_STEP_NUM="$(echo "$BS_STEP" | awk -F: '{ print $1}')"
            BS_STEP_FILE="$(echo "$BS_STEP" | awk -F: '{ print $2}')"
            if [ "$BS_STEP_FILE"  = "" ]
            then
               BS_STEP_FILE="$BS_STEP_NUM"
               if [ "$(basename "$BS_STEP_FILE" | grep -e "^[0-9][0-9]*-")" = "" ]
               then
                  BS_STEP_NUM=99
               else
                  BS_STEP_NUM=""
               fi  
            fi  
            # Set Full path of step file.
            BS_STEP_FILE="$(dirname "$(pwd)/$BS_STEP_FILE")/$(basename "$BS_STEP_FILE")"
            if [ ! -r "$BS_STEP_FILE" ]
            then
               Warning "Bootstrap file '$BS_STEP_FILE' was not found. Unable to add it to your user_data bootstrap."
            else
               mkdir -p ~/.build/bs_step/$$
               if [ "${BS_STEP_NUM}" = "" ]
               then
                  ln -sf "$BS_STEP_FILE" ~/.build/bs_step/$$/"$(basename "$BS_STEP_FILE").sh"
               else
                  ln -sf "$BS_STEP_FILE" ~/.build/bs_step/$$/${BS_STEP_NUM}-"$(basename "$BS_STEP_FILE").sh"
               fi  
               BOOTSTRAP_EXTRA=~/.build/bs_step/$$/
               Info "'$(basename "$BS_STEP_FILE")' added as extra user_data bootstrap step."
            fi  
            shift;shift;; 
        --) 
            shift; break;;
    esac
done

if [ ! -x "$MIME_SCRIPT" ]
then
   Error 1 "'$MIME_SCRIPT' is not executable. Check it."
fi

if [ "$APP_NAME" = "" ]
then
   Error 1 "The required box Name was not defined. Please set --box-name"
fi

if [ "$BUILD_CONFIG" = "" ]
then
   Error 1 "build configuration set not correctly set."
fi
if [ "$GITBRANCH" = "" ]
then
   CONFIG="$CONFIG_PATH/${APP_NAME}.${BUILD_CONFIG}.env"
else
   CONFIG="$CONFIG_PATH/${APP_NAME}.${BUILD_CONFIG}.${GITBRANCH}.env"
fi
if [ ! -r "$CONFIG" ]
then
   Info "Unable to load build configuration file."
   echo "Here are the list of valid configuration from '$CONFIG_PATH':"
   printf "%-10s | %-20s | %-10s\n--------------------------------------------\n" "BoxName" "ConfigName" "BranchName"
   ls -1 $CONFIG_PATH/*.env | sed 's|'"$CONFIG_PATH"'/\(.*\)\.env$|\1|g' | awk -F. '{ 
                                                                                     MID=$0;
                                                                                     gsub(sprintf("^%s.",$1), "",MID);
                                                                                     gsub(sprintf(".%s$",$NF),"",MID);
                                                                                     printf "%-10s | %-20s | %-10s\n",$1,MID,$NF
                                                                                    }'
   echo "--------------------------------------------
Set BoxName    with --box-name. Option required.
    ConfigName with --build-config. By default, ConfigName is 'bld'
    BranchName with --gitBranch or --gitBranchCur. By default, BranchName is 'master'"
   Error 1 "No file matching BoxName:${APP_NAME} ConfigName:${BUILD_CONFIG} BranchName:${GITBRANCH}. (${APP_NAME}.${BUILD_CONFIG}.${GITBRANCH}.env) Please check it."
fi

# TODO: Add validation of HPC variables set.
source "$CONFIG"
Info "$CONFIG loaded."

# Checking hpcloud configuration
HPC_Check

# Default required variables if not set from the config build file.
if [ "$FORJ_SECURITY_GROUP" = "" ]
then
   FORJ_SECURITY_GROUP='default'
fi
if [ "$FORJ_KEYPAIR" = "" ]
then
   FORJ_KEYPAIR='nova'
fi


# Check if FORJ_HPC is defined. If not, then the user HAVE to review the configuration file and update it as needed.

if [ "$FORJ_HPC" = "" ]
then
   Error 1 "The configuration file '$CONFIG' needs to be reviewed and updated.
Please, open '$CONFIG', read comments and update accordingly.

At least you need to set FORJ_HPC variable to the dedicated HPCloud account to use for your build. 
If this account doesn't exist, it will be created from 'hp' account. 
Then, you may need to redefine some HPCloud setting as listed in your configuration file as FORJ_HPC_*.

Example: If you do not have 'dev' (FORJ_HPC setting) and your 'hp' is set with a tenantID like 'ABCD1234'. But you want to use a different one for your build.
         So, set FORJ_HPC_TENANTID=GFJK5969 in your configuration will:
1. create 'dev' from 'hp' as 'dev' was inexistant.
2. update 'dev' to change tenantID from 'ABCD1234' to 'GFJK5969'
3. Then build your image with this 'dev' account setting.


Build aborted."
fi

# Check if $FORJ_HPC is already created.


if [ "$(hpcloud account | grep -e "^$FORJ_HPC$" -e "^$FORJ_HPC <= default")" = "" ]
then
   hpcloud account:copy hp $FORJ_HPC || Exit 1
   HPC_COPY=True
fi

HPC_Verify

if [ ! -d "$APP_NAME" ]
then
   Error 1 "You need to be in the directory containing the <BoxName>."
fi

if [ "$FORJ_FLAVOR" = "" ]
then
   Error 1 "FORJ_FLAVOR was not defined. Please update your build configuration file."
fi

if [ "$FORJ_BASE_IMG" = "" ]
then
   Error 1 "FORJ_BASE_IMG was not defined. Please update your build configuration file."
fi

if [ "$BUILD_ID" = "" ]
then
   Error 1 "Please set --build_ID or set BUILD_ID in your build configuration."
fi

# GITREPO is the variable used by cloudinit.conf to update bootstrap script.
GITREPO="$(echo "$GIT_REPO" | sed 's/\//\\\//g')"

Info "Checking environments"

# Checking hpcloud tools
HPCLOUD="$(which hpcloud)"

if [ "$HPCLOUD" = "" ]
then
   Error 1 "hpcloud installation is not installed or not in your PATH. Please check."
fi 

hpcloud account:verify $FORJ_HPC

if [ $? -ne 0 ]
then
   Error 2 "account $FORJ_HPC is not correctly configured. Please fix it and retry."
fi

if [ "$(grep az ~/.hpcloud/accounts/$FORJ_HPC)" != "" ]
then
   Warning "HPCloud account '$FORJ_HPC' is using 12.12"
   HPC_DETECTED=12.12
fi

printf "Checking servers"
# Checking if the build_ID exist. if so, returns an error.
if [ "$(hpcloud servers $BUILD_ID -d, -c id -a $FORJ_HPC | grep -e "have no servers" -e "are no servers")" = "" ]
then
   echo "
${LIGHTRED}ERROR${DFL_COLOR}: The build ID $BUILD_ID($PRIVIP) is already instanciated. Change the build ID or remove the existing instance.

You can ssh to the server with 
$ hpcloud servers:ssh $BUILD_ID -a $FORJ_HPC

To remove the server with
$ hpcloud servers:remove $BUILD_ID -a $FORJ_HPC
"

   ERO_IP="$(hpcloud servers $BUILD_ID -d , -c ips -a $FORJ_HPC)"
   PRIVIP="$(echo $ERO_IP | awk -F, '{ print $1 }')"
   if [ "$HPC_DETECTED" = 12.12 ]
   then
      PUBIP="$(echo $ERO_IP | awk -F, '{ print $2 }')"
   else
      PUBIP="$(hpcloud addresses -d , -c fixed_ip,floating_ip -a $FORJ_HPC | awk -F, '$1 ~ /^'"$PRIVIP"'$/ { print $2 }' )"
   fi
   if [ "$PUBIP" = "" ]
   then
      echo "There is no Public IP associated from '$PRIVIP'."
   else
      echo "This server has a public IP address '${PUBIP}'. You can access it directly with:
$ ssh ubuntu@$PUBIP -o StrictHostKeyChecking=no -i ~/.hpcloud/keypairs/${FORJ_KEYPAIR}.pem"
   fi
   exit 3
fi

if [ "$HPC_DETECTED" != 12.12 ] && [ "$FORJ_HPC_NET" != "" ]
then
   printf " networks"
 
   FORJ_HPC_NET_OUTP="$(hpcloud networks $FORJ_HPC_NET -a $FORJ_HPC -d , -c id,name)"
   FORJ_HPC_NETID="$(echo "$FORJ_HPC_NET_OUTP" | awk -F, '{print $1}')"
   if [ "$(echo "$FORJ_HPC_NET_OUTP" | grep -e ",$FORJ_HPC_NET *$" -e "^$FORJ_HPC_NET,")" = "" ]
   then
      echo
      Error 2 "The build script is trying to use a network '${FORJ_HPC_NET}' (FORJ_HPC_NET). But this one is not found. Please check with hpcloud tool."
   fi
fi

printf " flavors"
FORJ_FLAVOR_OUTP="$(hpcloud flavors $FORJ_FLAVOR -a $FORJ_HPC -d , -c id,name)"
FORJ_FLAVOR_ID="$(echo "$FORJ_FLAVOR_OUTP" | awk -F, '{print $1}')"
if [ "$(echo $FORJ_FLAVOR_OUTP | grep -e ",$FORJ_FLAVOR *$" -e "^$FORJ_FLAVOR,")" = "" ]
then
   echo
   Error 2 "The build script is trying to use a flavor '$FORJ_FLAVOR' (FORJ_FLAVOR), supposed to be xsmall. But this one is not found. Please check with hpcloud tool."
fi

printf " images"
# Checking the base image to use. If deprecated, a WARNING have to be sent.
BASE_IMG="$(echo "$FORJ_BASE_IMG" | sed 's/(/\\(/g
                                         s/)/\\)/g')"
FORJ_BASE_IMG_OUTP="$(hpcloud images "$BASE_IMG" -a $FORJ_HPC -d , -c id,name)"
FORJ_BASE_IMG_ID="$(echo "$FORJ_BASE_IMG_OUTP" | awk -F, '{print $1}')"
if [ "$(echo "$FORJ_BASE_IMG_OUTP" | grep -e ",$FORJ_BASE_IMG *$" -e "^$FORJ_BASE_IMG,")" = "" ]
then
   echo
   Error 2 "The build script is trying to use an image ID '$FORJ_BASE_IMG' (FORJ_BASE_IMG), supposed to be ubuntu 12.04 LTS. But this one is not found. Please check with hpcloud tool."
fi

printf " keypairs"
# Checking the nova key existence.
if [ "$(hpcloud keypairs ${FORJ_KEYPAIR} -a $FORJ_HPC | grep 'no keypairs')" != "" ]
then
  if [ "$FORJ_HPC_NOVA_KEYPUB" != "" ] && [ -r "$FORJ_HPC_NOVA_KEYPUB" ]
  then
     hpcloud keypairs:import ${FORJ_KEYPAIR} "$(cat $FORJ_HPC_NOVA_KEYPUB)" -a $FORJ_HPC
  else
     echo
     Error 3 "${FORJ_KEYPAIR} public key was not set, and FORJ_HPC_NOVA_KEYPUB ('$FORJ_HPC_NOVA_KEYPUB') is not valid or readable. Please do it yourself:
you can use an equivalent command to import it. You will need to provide the real PATH to your public key.

Ex: 
$ hpcloud keypairs:import ${FORJ_KEYPAIR} \"\$(cat nova-USWest-AZ3.pub )\" -a $FORJ_HPC"
  fi
fi

# Required by cloudinit.conf file.
BUILD_DIR=~/.build/$APPPATH/$$
mkdir -p $BUILD_DIR

printf "\n"

# Build user_data.
bootstrap_build

if [ "$BUILD_ID" = "" ]
then
   Error 255 "Internal Error. BUILD_ID is empty. Check if bootstrap file clear it up or not."
fi

if [ "$USER_DATA" != "" ]
then
   HPCLOUD_PAR="$HPCLOUD_PAR --userdata $USER_DATA"
fi  
if [ "$META_DATA" != "" ]
then
   HPCLOUD_PAR="$HPCLOUD_PAR --metadata $META_DATA"
fi  


Info "Starting '$BUILD_ID' build."
trap "Error 1 'Ctrl-C keystroke by user. Build killed.'" SIGINT
# Creating the instance. Use metadata/userdata from ../../bootstrap/eroPlus
if [ "$HPC_DETECTED" != 12.12 ] && [ $FORJ_HPC_NETID != "" ]
then
   hpcloud servers:add $BUILD_ID $FORJ_FLAVOR_ID -i $FORJ_BASE_IMG_ID -k ${FORJ_KEYPAIR} -n $FORJ_HPC_NETID -a $FORJ_HPC -s ${FORJ_SECURITY_GROUP} $HPCLOUD_PAR
else
   hpcloud servers:add $BUILD_ID $FORJ_FLAVOR_ID -i $FORJ_BASE_IMG_ID -k ${FORJ_KEYPAIR} -a $FORJ_HPC -s ${FORJ_SECURITY_GROUP} $HPCLOUD_PAR
fi

if [ $? -ne 0 ]
then
   Error 3 "Unable to start the '$BUILD_ID' box"
fi


BUILD_STATUS="STARTING"
printf "\r%s[K" "$BUILD_STATUS"

INSTANT_LOG=$BUILD_DIR/instantlog
# Loop to wait cloudinit to be done

typeset -i COLS=20

while [ 1 = 1 ]
do
  if [ "$BUILD_STATUS" = "ACTIVE (cloud_init)" ]
  then
     hpcloud servers:console $BUILD_ID 10  -a $FORJ_HPC> $INSTANT_LOG

     if [ "$TEST_BOX_SCRIPT" != "" ]
     then
        TEST_BOX_REPO="$(grep -e 'build.sh: test-box-repo=' $INSTANT_LOG | tail -n 1 | sed 's/^.*build.sh: test-box-repo=\(.*\)/\1/g')"
        if [ "$TEST_BOX_REPO" != "" ] 
        then
           TEST_BOX_DIR="${TEST_BOX[$TEST_BOX_REPO]}"
           if [ "$TEST_BOX_DIR" != "" ]
           then
              case "$TEST_BOX_DIR" in
                WARNED | DONE)
                 ;;
                *)
                 echo 'test-box: your box is waiting for a test-box repository. One moment.'
                 cd "$TEST_BOX_DIR"
                 if [ "$(git rev-parse --abbrev-ref HEAD| grep "testing-$(id -un)-$PUBIP")" != "" ]
                 then
                    Warning "test-box: Your local repo '$TEST_BOX_REPO' is on the testing branch. build.sh do not support it. Please do the test-box work manually from '$TEST_BOX_DIR'"
                    TEST_BOX[$TEST_BOX_REPO]=WARNED
                 fi
                 if [ "$(git branch --list testing-$(id -un)-$PUBIP)" != "" ]
                 then
                    Info "test-box: Removing old branch..."
                    git branch -d testing-$(id -un)-$PUBIP
                    if [ $? -ne 0 ]
                    then
                       Warning "test-box: Please review the issue about the testing branch and execute '$TEST_BOX_SCRIPT --push-to $PUBIP'"
                       TEST_BOX[$TEST_BOX_REPO]=WARNED
                    fi
                 fi
                 if [ "${TEST_BOX[$TEST_BOX_REPO]}" = $TEST_BOX_DIR ] # No warning, go on.
                 then
                    echo "Running : $TEST_BOX_SCRIPT --push-to $PUBIP --repo $TEST_BOX_REPO"
                    $TEST_BOX_SCRIPT --push-to $PUBIP --repo $TEST_BOX_REPO
                    if [ $? -ne 0 ]
                    then
                       Warning "test-box: 'test-box.sh' fails. Please review, and retry it manually."
                    fi
                    Info "test-box is done. check for errors. If needed, restart the test-box work manually to fix it."
                    TEST_BOX[$TEST_BOX_REPO]=DONE
                 fi
                 cd - >/dev/null
                 ;;
              esac
           else
              printf "\n"
              Warning "Manual test-box action required! Your box is currently waiting for repo '$TEST_BOX_REPO'
Usually, execute '$TEST_BOX_SCRIPT --push-to $PUBIP' where your repository update to test is located."
              TEST_BOX[$TEST_BOX_REPO]=WARNED
           fi
        fi
     fi

     cat $INSTANT_LOG | md5sum > ${INSTANT_LOG}.new
     if [ "$(cat ${INSTANT_LOG}.new)" != "$(cat ${INSTANT_LOG}.md5)" ]
     then
        CUR_STATE=.
        mv ${INSTANT_LOG}.new ${INSTANT_LOG}.md5
     else
        CUR_STATE=?
     fi

     # Build status summary display resize to the terminal cols
     INSTANT_STATUS="${INSTANT_STATUS}$CUR_STATE"
     typeset -i INSTANT_STATUS_CNT=$(echo "$INSTANT_STATUS" | wc -c)
     if [ "$TERM" != "" ] && [ "$TERM" != "dumb" ]
     then # reduce size by prefix string size. ie ACTIVE (cloud_init)
        let "COLS=$(tput cols)-22"
     fi
     if [ $INSTANT_STATUS_CNT -gt $COLS ]
     then
        let "REMOVE_CNT=INSTANT_STATUS_CNT-COLS"
       INSTANT_STATUS="$(echo "${INSTANT_STATUS}" | cut -c $REMOVE_CNT-)"
     fi   

     if [ "$(grep "cloud-init boot finished" ${INSTANT_LOG})" != "" ]
     then
        BUILD_STATUS="ACTIVE"
        break
     fi
     
     # Checking for IPs
     if [ "$PUBIP" = "" ] || [ "$PRIVIP" = "" ]
     then
        ERO_IP="$(hpcloud servers $BUILD_ID -d , -c ips -a $FORJ_HPC)"
        PRIVIP="$(echo $ERO_IP | awk -F, '{ print $1 }')"
        if [ "$HPC_DETECTED" != 12.12 ] && [ $FORJ_HPC_NETID != "" ]
        then
           if [ "$PUBIP" = "" ] && [ "$NEW_PUBIP" = "" ]
           then
              printf "\r"
              Info "Selecting a public IP to associate to your server."
              NEW_PUBIP="$(hpcloud addresses -d , -c fixed_ip,floating_ip -a $FORJ_HPC| grep "^," | awk -F, '{ if (FNR == 1 ) print $2 }')"
              if [ "$NEW_PUBIP" = "" ] && [ "$NEW_PUBIP_WARN" != True ]
              then
                 NEW_PUBIP_WARN=True
                 # attempt to add a new public ip address and allow for 30 seconds, otherwise, let the warning display
                 hpcloud addresses:add -a $FORJ_HPC
                 sleep 30
                 NEW_PUBIP="$(hpcloud addresses -d , -c fixed_ip,floating_ip -a $FORJ_HPC| grep "^," | awk -F, '{ if (FNR == 1 ) print $2 }')"
                 if [ "$NEW_PUBIP" = "" ]
                 then
                    Warning "Unable to identify an IP to assign from the pool. You need to extend or free up some IPs, to get a free one.
NOTE: The build process will continuously query to get a new IP. So, if you can free up an IP in parallel, do it now."
                 fi
              fi
           fi
        else
           PUBIP="$( echo $ERO_IP | awk -F, '{ print $2 }')" # This feature is not working well - IPs data sync is not done on time by openstack.
           NEW_PUBIP_ASSIGNED=True
           printf "\r"
           echo "Now, as soon as the server respond to the ssh port, you will be able to get a tail of the build with:
while [ 1 = 1 ]
do
  ssh ubuntu@$PUBIP -o StrictHostKeyChecking=no -i ~/.hpcloud/keypairs/${FORJ_KEYPAIR}.pem tail -f /var/log/cloud-init.log
  sleep 5
done"
        fi
     fi

     # Assigning Public IPs
     if [ "$PUBIP" = "" ] && [ "$NEW_PUBIP" != "" ] && [ "$PRIVIP" != "" ] && [ "$NEW_PUBIP_ASSIGNED" != True ]
     then
        Info "Assigning public IP '$NEW_PUBIP' to '${PRIVIP}'."
        # Getting the router port associated to the private IP.
        PRIVIP_PORT="$(hpcloud ports -d , -c 'id,fixed_ips' -a $FORJ_HPC | awk -F, '$3 ~ /^'"${PRIVIP}"'$/ { print $1 }')"
        if [ "$PRIVIP_PORT" = "" ]
        then
           Warning "Unable to get the Private IP route port number. I can't associate."
        else
           hpcloud addresses:associate "$NEW_PUBIP" "$PRIVIP_PORT" -a $FORJ_HPC
           NEW_PUBIP_ASSIGNED=True
           PUBIP="$NEW_PUBIP"
           echo "Now, as soon as the server respond to the ssh port, you will be able to get a tail of the build with:
while [ 1 = 1 ]
do
  ssh ubuntu@$PUBIP -o StrictHostKeyChecking=no -i ~/.hpcloud/keypairs/${FORJ_KEYPAIR}.pem tail -f /var/log/cloud-init.log
  sleep 5
done"
        fi
     fi

     # Public IP assigned.
     if [ "$PUBIP" != "" ] && [ "$PUBIP_INFO" != True ]
     then
        PUBIP_INFO=True
        Info "cloud-init is running. "
     fi
  else
     BUILD_STATUS=$(hpcloud servers $BUILD_ID -d , -c state -a $FORJ_HPC)
     if [ "$BUILD_STATUS" = ACTIVE ]
     then
        BUILD_STATUS="ACTIVE (cloud_init)"
        printf "\r"
        Info "cloud-init is starting. Waiting for a public IP assigned."
        INSTANT_STATUS="."
        rm -f ${INSTANT_LOG}.md5 ; touch ${INSTANT_LOG}.md5
     fi
  fi
  printf "\r%s[K" "$BUILD_STATUS $INSTANT_STATUS"
  sleep 5
done

printf "\r%s[J\n" "$BUILD_STATUS ($PUBIP)"

if [ "$DEBUG" = "True" ]
then
   echo "The server is built. You can connect using 'ssh ubuntu@$PUBIP -o StrictHostKeyChecking=no -i ~/.hpcloud/keypairs/${FORJ_KEYPAIR}.pem'.
To remove the server, use 'hpcloud servers:remove $BUILD_ID -a $FORJ_HPC'"
   Exit
fi

Info "$BUILD_ID is ready. Checking build status."

ssh ubuntu@$PUBIP -o StrictHostKeyChecking=no -i ~/.hpcloud/keypairs/${FORJ_KEYPAIR}.pem "sudo shutdown -h 0"
sleep 10


Info "Building the Image '${BUILD_PREFIX}$BUILD_IMAGE_SUFFIX'."
if [ "$(hpcloud images -d , -c id ${BUILD_PREFIX}$BUILD_IMAGE_SUFFIX  -a $FORJ_HPC| grep -e [0-9][0-9]*)" != "" ]
then
   echo "Removing the previous one..."
   hpcloud images:remove ${BUILD_PREFIX}$BUILD_IMAGE_SUFFIX -a $FORJ_HPC
fi
hpcloud images:add ${BUILD_PREFIX}$BUILD_IMAGE_SUFFIX $BUILD_ID -a $FORJ_HPC

# Loop to wait snapshot to be done
BUILD_STATUS=$(hpcloud images ${BUILD_PREFIX}$BUILD_IMAGE_SUFFIX -d , -c status -a $FORJ_HPC)
while [ "$BUILD_STATUS" != ACTIVE ]
do
  printf "\r%s[K" "$BUILD_STATUS"
  sleep 10
  BUILD_STATUS=$(hpcloud images ${BUILD_PREFIX}$BUILD_IMAGE_SUFFIX -d , -c status -a $FORJ_HPC)
done
echo

Info "Terminating the Image '${BUILD_ID}'."
hpcloud servers:remove $BUILD_ID  -a $FORJ_HPC

Info "'${BUILD_ID}' done."
Exit
