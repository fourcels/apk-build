#!/usr/bin/env bash

DOWNLOAD_DIR=download
DECODE_DIR=decode
DIST_DIR=dist
SIGN_KS=sign.jks
APP_DEBUG_FILE=app-debug.apk
APP_DEBUG_DOWNLOAD_URL=https://github.com/fourcels/Android-Mod-Menu-BNM/releases/latest/download/${APP_DEBUG_FILE}
declare -A apps

# Function to check if a command exists
check_command() {

  while [ "$#" -gt 0 ]; do
    if ! command -v "$1" >/dev/null 2>&1; then
      echo "$1 is not installed. Please install it to proceed."
      exit 1
    fi
    shift
  done
}

check_command curl apktool apksigner


{
  read
  while IFS=, read -ra line || [ -n "$line" ]
  do
    apps[$line]="${line[@]}"
  done
} < apps.csv


usage() {
  cat << EOF
Usage: $0 $(IFS="|"; echo "${!apps[*]}")

OPTIONS:
  -h  Show this help message

Example:
  $0 horny-villa
EOF
  exit 1
}

# Process options:
while getopts ":h" opt; do
  case $opt in
    h)
      usage
      ;;
    :)
      echo "Error: Option -$OPTARG requires an argument." >&2
      usage
      ;;
    \?)
      echo "Error: Invalid option: -$OPTARG" >&2
      usage
      ;;
  esac
done

shift $((OPTIND-1))

if [[ -z "$1" ]]; then
  usage
fi

read -r app_name app_activity app_download <<< ${apps[$1]}
if [[ -z "$app_name" ]]; then
  usage
fi

echo $app_name $app_activity $app_download

echo -e "Downloading ${APP_DEBUG_FILE}..."
if [[ ! -f ${APP_DEBUG_FILE} ]]; then
  curl -L $APP_DEBUG_DOWNLOAD_URL -o $APP_DEBUG_FILE
else
  echo -e "Exist ${APP_DEBUG_FILE}, skip download."
fi


echo -e "\nDownloading latest ${app_name}..."
gameFile=$(curl -w "%{url_effective}\n" -I -L -s -S $app_download -o /dev/null)
if [ $? -ne 0 ]; then
  echo -e "Cannot get latest ${app_name}, try again."
  exit 1
fi

gameFile=$(basename $gameFile)
downloadFile=${DOWNLOAD_DIR}/${gameFile}

if [[ ! -f ${downloadFile} ]]; then
  curl -L $app_download -o $downloadFile
  if [ $? -ne 0 ]; then
    echo -e "Cannot get latest ${app_name}, try again."
    exit 1
  fi
else
  echo -e "Exist $downloadFile, skip download."
fi

appDebugOutput=$DECODE_DIR/${APP_DEBUG%.*}
echo -e "\nDecoding ${APP_DEBUG_FILE} to ${appDebugOutput}..."
apktool d -f $APP_DEBUG_FILE -o $appDebugOutput

gameOutput=$DECODE_DIR/${gameFile%.*}
echo -e "\nDecoding ${gameFile} to ${gameOutput}..."
apktool d -f $downloadFile -o ${gameOutput}

echo -e "\nUpdate ${gameOutput}..."
libName=lib${app_name}.so
echo -e "Copy ${libName} to libModBNM.so"
find $gameOutput/lib/* -maxdepth 0 ! -name "arm64-v8a" -exec rm -rf '{}' +
cp $appDebugOutput/lib/arm64-v8a/${libName} $gameOutput/lib/arm64-v8a/libModBNM.so
echo -e "Copy smali_classes to ${gameOutput}"
cp -r $appDebugOutput/smali_classes* $gameOutput
gameActivityFile=$gameOutput/smali/${gameActivity//./\/}.smali
echo -e "Edit ${gameActivityFile}"
sed -i '' '/.method protected onCreate/a\
invoke-static {p0}, Lcom/android/support/Main;->start(Landroid/content/Context;)V' $gameActivityFile

echo -e "\nBuild and Sign ${gameFile}..."
apktool b -f ${gameOutput}

gameDistFile=${gameOutput}/dist/${gameFile}
signOutFile=${DIST_DIR}/${gameFile}
mkdir -p ${DIST_DIR}

apksigner sign --ks ${SIGN_KS} --ks-pass "pass:gaohong" --v4-signing-enabled false --out ${signOutFile} ${gameDistFile}


echo -e "\nClear ${DECODE_DIR} dir..."
rm -rf $DECODE_DIR

echo -e "\nSuccess build ${signOutFile}"