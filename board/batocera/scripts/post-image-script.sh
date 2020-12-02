#!/bin/bash -e

# PWD = source dir
# BASE_DIR = build dir
# BUILD_DIR = base dir/build
# HOST_DIR = base dir/host
# BINARIES_DIR = images dir
# TARGET_DIR = target dir

BATOCERA_BINARIES_DIR="${BINARIES_DIR}/batocera"

# clean the target directory images/batocera
if test -d "${BATOCERA_BINARIES_DIR}"
then
    rm -rf "${BATOCERA_BINARIES_DIR}" || exit 1
fi
mkdir -p "${BATOCERA_BINARIES_DIR}" || exit 1

# find images to build
BATOCERA_TARGET=$(grep -E "^BR2_PACKAGE_BATOCERA_TARGET_[A-Z_0-9]*=y$" "${BR2_CONFIG}" | grep -vE "_ANY=" | sed -e s+'^BR2_PACKAGE_BATOCERA_TARGET_\([A-Z_0-9]*\)=y$'+'\1'+)
BATOCERA_IMAGES_TARGETS=$(grep -E "^BR2_TARGET_BATOCERA_IMAGES[ ]*=[ ]*\".*\"[ ]*$" "${BR2_CONFIG}" | sed -e s+"^BR2_TARGET_BATOCERA_IMAGES[ ]*=[ ]*\"\(.*\)\"[ ]*$"+"\1"+)
if test -z "${BATOCERA_IMAGES_TARGETS}"
then
    echo "no BR2_TARGET_BATOCERA_IMAGES defined." >&2
    exit 1
fi

# build images
SUFFIXVERSION=$(cat "${TARGET_DIR}/usr/share/batocera/batocera.version" | sed -e s+'^\([0-9\.]*\).*$'+'\1'+) # xx.yy version
SUFFIXTARGET=$(echo "${BATOCERA_TARGET}" | tr A-Z a-z)
SUFFIXDATE=$(date +%Y%m%d)
for BATOCERA_TARGET in ${BATOCERA_IMAGES_TARGETS}
do
    TARGETSHORTNAME=$(basename "${BATOCERA_TARGET}")
    echo "creating image for target ${BATOCERA_TARGET}..." >&2
    SUFFIXIMG="-${SUFFIXVERSION}-${SUFFIXTARGET}-${TARGETSHORTNAME}-${SUFFIXDATE}"
    BATOCERA_POST_IMAGE_SCRIPT="${BR2_EXTERNAL_BATOCERA_PATH}/board/batocera/${BATOCERA_TARGET}/post-image-script.sh"

    # build the .img
    bash "${BATOCERA_POST_IMAGE_SCRIPT}" "${HOST_DIR}" "${BR2_EXTERNAL_BATOCERA_PATH}/board/batocera/${BATOCERA_TARGET}" "${BUILD_DIR}" "${BINARIES_DIR}" "${TARGET_DIR}" "${BATOCERA_BINARIES_DIR}" || exit 1
    mv "${BATOCERA_BINARIES_DIR}/batocera.img" "${BATOCERA_BINARIES_DIR}/batocera${SUFFIXIMG}.img" || exit 1
    gzip "${BATOCERA_BINARIES_DIR}/batocera${SUFFIXIMG}.img" || exit 1

    # md5
    for FILE in "${BATOCERA_BINARIES_DIR}/boot.tar.xz" "${BATOCERA_BINARIES_DIR}/batocera${SUFFIXIMG}.img.gz"
    do
	echo "creating ${FILE}.md5"
	CKS=$(md5sum "${FILE}" | sed -e s+'^\([^ ]*\) .*$'+'\1'+)
	echo "${CKS}" > "${FILE}.md5"
	echo "${CKS}  $(basename "${FILE}")" >> "${BATOCERA_BINARIES_DIR}/MD5SUMS"
    done
done

cp "${TARGET_DIR}/usr/share/batocera/batocera.version" "${BATOCERA_BINARIES_DIR}" || exit 1
"${BR2_EXTERNAL_BATOCERA_PATH}"/scripts/linux/systemsReport.sh "${PWD}" "${BATOCERA_BINARIES_DIR}" || exit 1

# pcsx2 package
if grep -qE "^BR2_PACKAGE_PCSX2=y$" "${BR2_CONFIG}"
then
	echo "building the pcsx2 package..."
	"${BR2_EXTERNAL_BATOCERA_PATH}"/board/batocera/scripts/doPcsx2package.sh "${TARGET_DIR}" "${BINARIES_DIR}/pcsx2" "${BATOCERA_BINARIES_DIR}" || exit 1
fi

# wine package
if grep -qE "^BR2_PACKAGE_WINE_LUTRIS=y$" "${BR2_CONFIG}"
then
	if grep -qE "^BR2_x86_i686=y$" "${BR2_CONFIG}"
	then
		echo "building the wine package..."
		"${BR2_EXTERNAL_BATOCERA_PATH}"/board/batocera/scripts/doWinepackage.sh "${TARGET_DIR}" "${BINARIES_DIR}/wine" "${BATOCERA_BINARIES_DIR}" || exit 1
	fi
fi

exit 0
