#!/bin/bash

g_remove_pkg_cmd="rpm -e --allmatches --nodeps"
g_is_installed_cmd="rpm -q"
kernel_src_pkg="kernel-mft"
mft_pkgs=(mft-oem mft  mft-autocomplete)

if [[ -x /usr/bin/lsb_release ]]; then
    if [[ `lsb_release -s -i | tr '[:upper:]' '[:lower:]'` == ubuntu ]] || [[ `lsb_release -s -i | tr '[:upper:]' '[:lower:]'` == debian ]]; then
        g_package_type="deb"
    fi
fi
if [[ g_package_type != "deb" ]] && [[ -f /etc/os-release ]]; then
# In some cases lsb_release is not available on Debian machine so we need to check os-release
    if [[ `grep -is "ubuntu\|debian" /etc/os-release` ]]; then
        g_package_type="deb"
    fi
fi
if [[ g_package_type != "deb" ]]; then
    if [[ `cat /etc/issue | head -1` == *Debian* ]] || [[ -f /usr/bin/apt-get ]] || [[ -f /etc/debian_version ]]; then
        g_package_type="deb"
    fi
fi

if [[ ${g_package_type} == "deb" ]]; then
    g_remove_pkg_cmd="dpkg --purge"
    g_is_installed_cmd="dpkg -s"
    kernel_src_pkg="kernel-mft-dkms"
fi

function pkg_is_installed () {
    package_name=$1
    ${g_is_installed_cmd} ${package_name} &> /dev/null
    return $?
}

function check_pkgs_present() {
    while [ "$1" ]; do
        package_name=$1
        pkg_is_installed ${package_name}; RC=$?
        if [ "${RC}" == "0" ]; then
            echo "-W- Failed to remove the package \"${package_name}\", try to remove it manually."
        fi
        shift
    done
}
mft_pkgs+=(${kernel_src_pkg})
echo "-I- Removing MFT package ....."
for pkg in ${mft_pkgs[*]}
do
    pkg_is_installed ${pkg}; RC=$?
    if [ "${RC}" == "0" ]; then
        echo "-I- Removing ${pkg} ..."
        ${g_remove_pkg_cmd} ${pkg}
    fi
    shift
done

check_pkgs_present ${mft_pkgs[*]}
