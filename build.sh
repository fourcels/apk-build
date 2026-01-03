#!/usr/bin/env bash

DOWNLOAD_DIR=download
OUTPUT_DIR=output
DIST_DIR=dist
SIGN_KS=sign.jks
APP_DEBUG=apk-debug.apk
APP_DEBUG_FILE=${DOWNLOAD_DIR}/${APP_DEBUG}
APP_DEBUG_DOWNLOAD_URL=https://github.com/fourcels/Android-Mod-Menu-BNM/releases/latest/download/app-debug.apk
gameName=horny-villa
gameActivity=com.unity3d.player.UnityPlayerActivity
downloadUrl="https://www.nutaku.net/games/horny-villa/app-update/"

usage() {
  cat <<EOF
Usage: $0 [-h] [-p <password>]

OPTIONS:
  -h  Show this help message
  -p  keystore password (requires an argument)
  -g  game name (horny-villa|ark-recode|mafia-queens)

Example:
  $0 -p password -g horny-villa
EOF
  exit 1
}

# Process options:
while getopts ":p:g:h" opt; do
  case $opt in
    p)
      ksPass="$OPTARG"
      ;;
    g)
      gameName="$OPTARG"
      case $gameName in
        horny-villa)
          gameActivity=com.unity3d.player.UnityPlayerActivity
          downloadUrl="https://www.nutaku.net/games/horny-villa/app-update/"
          ;;
        ark-recode)
          gameActivity=com.nutaku.unity.UnityPlayerActivity
          downloadUrl="https://www.nutaku.net/games/ark-recode/app-update/"
          ;;
        mafia-queens)
          gameActivity=com.unity3d.player.UnityPlayerActivity
          downloadUrl="https://www.nutaku.net/games/mafia-queens/app-update/"
          ;;
        *)
          usage
          ;;
      esac
      ;;
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

echo -e "Downloading ${APP_DEBUG}..."
if [[ ! -f ${APP_DEBUG_FILE} ]]; then
  curl -L $APP_DEBUG_DOWNLOAD_URL -o $APP_DEBUG_FILE
else
  echo -e "Exist ${APP_DEBUG_FILE}, skip download."
fi


echo -e "\nDownloading latest ${gameName}..."
gameFile=$(curl -w "%{url_effective}\n" -I -L -s -S $downloadUrl -o /dev/null)
if [ $? -ne 0 ]; then
  echo -e "Cannot get latest ${gameName}, try again."
  exit 1
fi

gameFile=$(basename $gameFile)
downloadFile=${DOWNLOAD_DIR}/${gameFile}

if [[ ! -f ${downloadFile} ]]; then
  curl -L $downloadUrl -o $downloadFile
  if [ $? -ne 0 ]; then
    echo -e "Cannot get latest ${gameName}, try again."
    exit 1
  fi
else
  echo -e "Exist $downloadFile, skip download."
fi

appDebugOutput=$OUTPUT_DIR/${APP_DEBUG%.*}
echo -e "\nDecoding ${APP_DEBUG}..."
apktool d -f $APP_DEBUG_FILE -o $appDebugOutput

gameOutput=$OUTPUT_DIR/${gameFile%.*}
echo -e "\nDecoding ${gameFile} to ${gameOutput}..."
apktool d -f $downloadFile -o ${gameOutput}

echo -e "\nUpdate ${gameOutput}..."
libName=lib${gameName}.so
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
if [[ -n "$ksPass" ]]; then
  apksigner sign --ks ${SIGN_KS} --ks-pass "pass:${ksPass}" --v4-signing-enabled false --out ${signOutFile} ${gameDistFile}
else
  apksigner sign --ks ${SIGN_KS} --v4-signing-enabled false --out ${signOutFile} ${gameDistFile}
fi

echo -e "\nSuccess build ${signOutFile}"