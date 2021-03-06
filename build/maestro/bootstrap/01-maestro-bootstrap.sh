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
# Identify branch to use for GIT clones

# Reading meta-data
GITBRANCH="$(GetJson /meta-boot.js gitbranch master)"
MAESTRO_LINK="$(GetJson /meta-boot.js maestrolink "https://review.forj.io/p/forj-oss/maestro")"

# Show instructions runs
set -x 

# Get maestro repository for bootstrap

git config --global http.sslVerify false # Required because FORJ ssl is selfsigned.
mkdir -p /opt/config/production/git
chmod 2775 /opt/config/production/git
_CWD=$(pwd)
cd /opt/config/production/git

GitLinkCheck $MAESTRO_LINK
if [ ! $? -eq 0 ] 
then
   echo "INFO: using default MAESTRO git url"
   MAESTRO_LINK="https://review.forj.io/p/forj-oss/maestro"
fi

CloneRepo maestro $MAESTRO_LINK $GITBRANCH
cd maestro
git config core.autocrlf false

mkdir /opt/config/production/puppet/
ln -s /opt/config/production/git/maestro/puppet/manifests /opt/config/production/puppet
set +x
