#!/bin/bash -ex

# This is a strip down version of
# https://github.com/couchbase/voltron/blob/master/server-linux-package.sh
# This script is used by couchbase-edge-server-linux on Mobile Jenkins.
# Required env (set by the job): VERSION, BLD_NUM, WORKSPACE

# Process template dir: copy each .tmpl to target dir with sed substitution.
process_templates() {
    local template_dir="$1"
    local target_dir="$2"
    pushd "${template_dir}"
    for f in *; do
        local target="${target_dir}/${f%.tmpl}"
        sed \
            -e "s,@@PRODUCT_VERSION@@,${VERSION}-${BLD_NUM},g" \
            -e "s,@@VERSION@@,${VERSION},g" \
            -e "s,@@RELEASE@@,${BLD_NUM},g" \
            -e "s,@@PREFIX@@,${PREFIX},g" \
            -e "s,@@PRODUCT@@,${PRODUCT},g" \
            -e "s,@@PRODUCT_BASE@@,couchbase,g" \
            "${f}" > "${target}"
        chmod a+x "${target}"
    done
    popd
}

# Main script
PRODUCT=${PRODUCT:-couchbase-edge-server}
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ARCH=$(uname -m)
PREFIX="/opt/${PRODUCT}"

# Validate required environment variables
for var in VERSION BLD_NUM WORKSPACE; do
    if [[ -z "${!var:-}" ]]; then
        echo "ERROR: $var is not set." >&2
        exit 1
    fi
done

for PKG in rpm deb; do
    PACKAGE_ROOT="/opt/${PKG}-chroot/${PKG}-package"
    PACKAGE_ROOT_FOR_CMD="/${PKG}-package"
    sudo rm -rf "${PACKAGE_ROOT}"
    sudo mkdir -p "${PACKAGE_ROOT}"
    sudo chown $(id -u):$(id -g) "${PACKAGE_ROOT}"

    case "${PKG}" in
        rpm)
            mkdir -p ${PACKAGE_ROOT}/rpmbuild/SOURCES
            mkdir -p ${PACKAGE_ROOT}/rpmbuild/BUILD
            mkdir -p ${PACKAGE_ROOT}/rpmbuild/BUILDROOT
            mkdir -p ${PACKAGE_ROOT}/rpmbuild/RPMS/${ARCH}
            process_templates ${SCRIPT_DIR}/rpm_templates ${PACKAGE_ROOT}
            cp ${SCRIPT_DIR}/service/${PRODUCT}.service ${PACKAGE_ROOT}/rpmbuild/SOURCES/.
            cp -rp ${WORKSPACE}/edge-server/install ${PACKAGE_ROOT}/${PRODUCT}
            tar -C "${PACKAGE_ROOT}" -czf "${PACKAGE_ROOT}/rpmbuild/SOURCES/${PRODUCT}_${VERSION}.tar.gz" ${PRODUCT}
            PACKAGE_CMD="rpmbuild --define '_topdir ${PACKAGE_ROOT_FOR_CMD}/rpmbuild' -bb ${PACKAGE_ROOT_FOR_CMD}/rpm.spec"
            ;;

        deb)
            mkdir -p "${PACKAGE_ROOT}/debianbuild/debian"
            mkdir -p "${PACKAGE_ROOT}/debianbuild/opt"
            process_templates ${SCRIPT_DIR}/deb_templates ${PACKAGE_ROOT}/debianbuild/debian
            cp ${SCRIPT_DIR}/service/${PRODUCT}.service ${PACKAGE_ROOT}/debianbuild/debian/.
            cp -rp ${WORKSPACE}/edge-server/install ${PACKAGE_ROOT}/debianbuild/opt/${PRODUCT}
            PACKAGE_CMD="cd ${PACKAGE_ROOT_FOR_CMD}/debianbuild && dpkg-buildpackage -b -uc -d"
            ;;
    esac

    # `LC_ALL=C` is needed because the chroots don't have full locale information.
    # `sudo chroot` is needed to enter the chroot jail, which requires root privs.
    LC_ALL=C sudo /usr/sbin/chroot /opt/${PKG}-chroot su couchbase -c "${PACKAGE_CMD}"
done
