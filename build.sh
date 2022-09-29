#!/bin/bash
echo ""
echo "LineageOS 18.x Unified Buildbot - LeaOS version"
echo "Executing in 5 seconds - CTRL-C to exit"
echo ""
sleep 5

if [ $# -lt 1 ]
then
    echo "Not enough arguments - exiting"
    echo ""
    exit 1
fi

MODE=${1}
NOSYNC=false
PERSONAL=false
ICEOWS=true
for var in "${@:2}"
do
    if [ ${var} == "nosync" ]
    then
        NOSYNC=true
    fi
done

echo "Building with NoSync : $NOSYNC - Mode : ${MODE}"



# Abort early on error
set -eE
trap '(\
echo;\
echo \!\!\! An error happened during script execution;\
echo \!\!\! Please check console output for bad sync,;\
echo \!\!\! failed patch application, etc.;\
echo\
)' ERR

START=`date +%s`
BUILD_DATE="$(date +%Y%m%d)"
WITHOUT_CHECK_API=true
WITH_SU=true


prep_build() {
	echo "Preparing local manifests"
	rm -rf .repo/local_manifests
	mkdir -p .repo/local_manifests
	cp ./lineage_build_leaos/local_manifests_leaos/*.xml .repo/local_manifests
	echo ""

	echo "Syncing repos"
	repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
	echo ""

	echo "Setting up build environment"
	source build/envsetup.sh &> /dev/null
	mkdir -p ~/build-output
	echo ""
	
	repopick -t 13-qs-lightmode
	repopick -t 13-powermenu-lightmode
	repopick 321337 -f # Deprioritize important developer notifications
	repopick 321338 -f # Allow disabling important developer notifications
	repopick 321339 -f # Allow disabling USB notifications
	repopick 331534 -f # SystemUI: Add support to add/remove QS tiles with one tap
	repopick 334388 -f # SystemUI: Fix QS header clock color
}

apply_patches() {
    echo "Applying patch group ${1}"
    bash ./lineage_build_unified/apply_patches.sh ./lineage_patches_unified/${1}
}

prep_device() {
    :
}

prep_treble() {
    :
}

finalize_device() {
    :
}

finalize_treble() {
    :
}

build_device() {
    brunch ${1}
    mv $OUT/lineage-*.zip ~/build-output/lineage-20.0-$BUILD_DATE-UNOFFICIAL-${1}$($PERSONAL && echo "-personal" || echo "").zip
}

build_treble() {
    case "${1}" in
        ("64BVS") TARGET=gsi_arm64_vS;;
        ("64BVZ") TARGET=gsi_arm64_vZ;;
        ("64BVN") TARGET=gsi_arm64_vN;;
        (*) echo "Invalid target - exiting"; exit 1;;
    esac
    lunch lineage_${TARGET}-userdebug
    make -j$(nproc --all) systemimage
    mv $OUT/system.img ~/build-output/LeaOS-20.0-$BUILD_DATE-${TARGET}.img
}

if ${NOSYNC}
then
    echo "ATTENTION: syncing/patching skipped!"
    echo ""
    echo "Setting up build environment"
    source build/envsetup.sh &> /dev/null
    echo ""
else
    prep_build
    echo "Applying patches"
    prep_treble

    finalize_treble
    echo ""
fi

for var in "${@:2}"
do
    if [ ${var} == "nosync" ]
    then
        continue
    fi
    echo "Starting $(${PERSONAL} && echo "personal " || echo "")build for ${MODE} ${var}"
    build_${MODE} ${var}
done
ls ~/build-output | grep 'LeaOS' || true
if [ ${MODE} == "treble" ]
then
    echo $START > ~/build-output/ota-timestamp.txt
fi

END=`date +%s`
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))
echo "Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo ""
