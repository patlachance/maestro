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
# This script contains process for building the user-data bootstrap.
# 

function bootstrap_build
{
Info "Preparing cloudinit mime."

cd $APP_NAME

if [ ${#META[@]} -gt 0 ]
then
   META_DATA="$(echo "${META[@]}" | sed 's/ /,/g')"
   Info "Meta-data set:
$META_DATA"
   META_JSON="{\"$(echo $META_DATA|sed 's/ *= */":"/g
                                        s/ *, */","/g')\"}"
fi
# Maestro BootHook - Set hostname and workaround missing meta.js
sed 's!${metadata-json}!'"$META_JSON"'!g' $BIN_PATH/build-tools/boothook.sh > $BUILD_DIR/boothook.sh
TOMIME="$BUILD_DIR/boothook.sh:text/cloud-boothook" 

# Add cloudconfig.yaml - Inform cloud-init to no update hostname & install basic packages.
if [ -f cloudconfig.yaml ]
then
   TOMIME="$TOMIME cloudconfig.yaml" 
fi

# Maestro boot. Use maestro/{#}-*.sh to build a shell script added to the cloud-init mime file.
BOOT_BOX=$BUILD_DIR/boot_${APP_NAME}.sh

rm -f $BOOT_BOX

if [ "$BOOTSTRAP_DIR" != "" ]
then
   if [ "$(find $BOOTSTRAP_DIR -maxdepth 1 -type f -name \*.sh -exec basename {} \; | wc -l)" -eq 0 ]
   then
      Warning "'$BOOTSTRAP_DIR' contains no bootstrap files. Please check it."
   else
      Info "Completing Maestro basic cloud-init with '$BOOTSTRAP_DIR'"
   fi
fi

BOOT_FILES="$(find bootstrap $BOOTSTRAP_DIR -maxdepth 1 -type f -name \*.sh -exec basename {} \; | sort -u)"

echo "Read boot script: "
for BOOT_FILE in $BOOT_FILES
do
   for DIR in bootstrap $BOOTSTRAP_DIR
   do
      if [ ! -f $BOOT_BOX ]
      then
         printf "#!/bin/bash\n# This script was automatically generated by ${0}. Do not edit it.\n" > $BOOT_BOX
      fi
      if [ -r $DIR/$BOOT_FILE ]
      then
         printf "\n#############\n# bootstrap builder: include $DIR/$BOOT_FILE\n#############\n\n" >> $BOOT_BOX
         cat $DIR/$BOOT_FILE >> $BOOT_BOX
         echo "Included : $DIR/$BOOT_FILE"
      fi
   done
done
printf "\n"
if [ -r $BOOT_BOX ]
then
   Info "$BOOT_BOX added to the mime."
   TOMIME="$TOMIME $BOOT_BOX" 
fi

for FILE in $TOMIME
do
   if [ "$(echo $FILE| grep ':')" = "" ]
   then
      TYPE=""
   else
      TYPE=$(echo $FILE| sed 's/^.*:/:/g')
   fi  
   FILE=$(echo $FILE| sed 's/:.*//g')
   if [ "$(echo $FILE | cut -c1)" = / ]
   then # Metadata file built to use
       REAL_FILE="$(echo "$BUILD_DIR/$(basename $FILE)")"
   else # Source file to use
      REAL_FILE="$(echo "$FILE")"
   fi
   if [ ! -f "$REAL_FILE" ]
   then
      printf "\ncloudinit.conf: $REAL_FILE not found.\n"
      exit 1
   fi
   FILES="$FILES $REAL_FILE$TYPE"
   printf "$FILE\e[32m$TYPE\e[0m "
done

$MIME_SCRIPT $FILES -o $BUILD_DIR/userdata.mime
if [ $? -ne 0 ]
then
   echo "cloudinit.conf: Error while building $BUILD_DIR/userdata.mime with 'write-mime-multipart.py'. Please check."
   exit 1
fi
echo " > $BUILD_DIR/userdata.mime"

USER_DATA=$BUILD_DIR/userdata.mime

}

