#!/bin/bash

#                 - Mellanox Confidential and Proprietary -
# 
# Copyright (C) Jan 2013, Mellanox Technologies Ltd.  ALL RIGHTS RESERVED.
# 
# Except as specifically permitted herein, no portion of the information,
# including but not limited to object code and source code, may be reproduced,
# modified, distributed, republished or otherwise exploited in any form or by
# any means for any purpose without the prior written permission of Mellanox
# Technologies Ltd. Use of software subject to the terms and conditions
# detailed in the file "LICENSE.txt".


# Initiate global variables.
# pointing to the dir where this install script resides.
g_package_orig_dir=`cd "${0%*/*}";pwd`
g_install_kernel=1
g_install_user=1
g_tmp_dir="/tmp/mft.$$.logs"
g_only_for_source=0
g_oem_install=0
g_pcap_install=0
g_autocomplete_install=1
g_old_mft_package="mft"
g_machine_name=`uname -m`
g_kernel_version=`uname -r`
g_skip_pkg_inst_failure=false
g_install_flag=""
g_build_flag=""

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
    if [ ${g_machine_name} == "x86_64" ]; then
        g_pckg_suffix="amd64"
    elif [ ${g_machine_name} == "aarch64" ]; then
        g_pckg_suffix="arm64"
    elif [ ${g_machine_name} == "ppc64le" ]; then
        g_pckg_suffix="ppc64le"
    elif [ ${g_machine_name} == "ppc64" ]; then
        g_pckg_suffix="ppc64"
    else
        echo "-E- This script does not support 32 bit Ubuntu/Debian"
        exit 1
    fi
    g_pkg_dir_name="DEBS"
    ####################################
    # Check if package is installed cmds
    ####################################
    g_is_installed_cmd="dpkg -s"
    g_is_all_installed_cmd="dpkg -l"
    g_list_files_cmd="dpkg -L"
    g_uninstall_cmd="dpkg -r"
    g_purge_cmd="dpkg --purge"
    g_install_cmd="dpkg -i"
    ########################################
    # Ubuntu/Debian depended packages Area #
    ########################################
    g_dep_ins_cmd="apt-get install"
    g_dep_pkg_list=()
    g_dep_kernel_pkg_list="gcc make dkms"
    g_dep_kernel_source_pkg_list="linux-headers linux-headers-generic"
else
    g_package_type="rpm"
    g_pckg_suffix=${g_machine_name} # On 32 bit machines this variable will be updated in the function update_machine_name()
    if [ ${g_machine_name} == "aarch64" ]; then
        g_pckg_suffix="arm64"
    fi
    g_pkg_dir_name="RPMS"
    ####################################
    # Check if package is installed cmds
    ####################################
    g_is_installed_cmd="rpm -q"
    g_is_all_installed_cmd="rpm -qa"
    g_list_files_cmd="rpm -ql"
    g_uninstall_cmd="rpm -e --allmatches"
    g_purge_cmd="rpm -e --allmatches --nodeps --noscripts"
    g_install_cmd="rpm -Uvh --verbose"
    ########################################
    # RHEL depended packages Area          #
    ########################################
    g_dep_ins_cmd="yum install"
    g_dep_pkg_list=()
    g_dep_kernel_pkg_list="gcc rpm-build make"
    g_dep_kernel_source_pkg_list="kernel-devel-`uname -r`"
    ########################################
    # SLES depended packages Area          #
    ########################################
    if [[ `cat /etc/issue` == *"SUSE"* ]] || [[ `cat /etc/*release` == *"SUSE"*  ]]; then
        g_dep_ins_cmd="yast -i"
        g_dep_pkg_list=()
        g_dep_kernel_pkg_list="rpm make"
        g_dep_kernel_source_pkg_list="kernel-source"
        # SLES 12 has different package for rpm-build, all other SLES has rpm-build in rpm package
        if [ -f /etc/os-release ]; then
            if [[ `cat /etc/os-release` == *"sles:12"* ]]; then
                g_dep_ins_cmd="zypper --non-interactive install"
                g_dep_kernel_pkg_list="rpm rpm-build make"
            fi
        fi
    fi
    ########################################
    # WindRiver depended packages Area     #
    ########################################
    if [[ `cat /etc/issue` == *"Wind River"* ]]; then
        g_install_flag="--nodeps"
        g_build_flag="--nodeps"
        g_dep_kernel_pkg_list="rpm make toolchain-wrappers"
    fi
fi

g_mft_user="mft"
g_mft_oem="mft-oem"
g_pcap="mft-pcap"
g_autocomplete="mft-autocomplete"
g_mft_kernel="kernel-mft"
g_mft_kernel_dkms="kernel-mft-dkms"
g_mft_version="4.27.0"
g_mft_rel="83"
g_prefix=""
g_rebuild_srpm=0
g_out_dir="/tmp"


# TODO: Add mft internal package uninstall
# TODO: How should I behave when an command fails.
# TODO: Add a cleanup option.

# The functions implementations

function echo_info () {
    echo "-I- $1"
}
function echo_warning () {
    echo "-W- $1"
}
function echo_debug () {
    echo "-D- $1" &> /dev/null
}
function echo_error () {
    echo "-E- $1" 1>&2
}

function safe_rm_rf() {
    dir="$1"
    case ${dir//\//} in
        usr|usrlocal|opt|bin|etc|lib|lib64|local|misc|sbin|var|boot|root|""|tmp)
        echo_error "Tried to remove directory $dir. Deletion aborted. Make sure the right destination paths were given"
        return 1
    esac
    /bin/rm -rf "${dir}"
    return 0
}


function check_arg() {
    if [ -z $2 ] || [[ "$2" == -* ]]; then
        echo "-E- Missing parameter after \"$1\" switch."
    exit 1
    fi
}

g_pref_op="--prefix"
g_help_op="--help"
g_tmp_dir_op="--tmpdir"
g_no_user_op="--without-user"
g_no_kernel_op="--without-kernel"
g_rebuild_srpm_op="--rebuild-srpm"
g_out_dir_rebuild_op="--srpm-out-dir"
g_oem_install_op="--oem"
g_pcap_install_op="--with-pcap"
g_autocomplete_install_op="--without-autocomplete"
g_extra_help_text=""

function print_help () {
     cat<<EOF
Usage: install.sh [${g_pref_op} <install-dir>][${g_help_op}]
                  [${g_no_kernel_op}][${g_no_user_op}]
Options:
    ${g_pref_op} <dir>           : Place bin/lib/include into <dir>.
    ${g_help_op}                   : Print this message.
    ${g_no_user_op}           : Do not install user modules.
    ${g_no_kernel_op}         : Do not build kernel modules. PCI devices access will not be enabled.
    ${g_rebuild_srpm_op}           : Rebuild the SRPM of MFT.
    ${g_out_dir_rebuild_op}           : Out directory for the rebuilt SRPM (default: /tmp).
    ${g_oem_install_op}                    : Install advanced tools - intended for OEMs.
    ${g_pcap_install_op}              : Install PCAP support
    ${g_autocomplete_install_op}      : Do not install autocomplete module.
    ${g_extra_help_text}
EOF

}

# get_user_options: Get the user option and updates the global variable to let the
#                   isntall function install the needed RPMs.
function get_user_options () {
    while [ "$1" ]; do
        case $1 in
            "${g_help_op}")
                print_help
                exit 0
                ;;
            "${g_pref_op}")
                check_arg $1 $2
                g_prefix=$2
                shift
                ;;
            "${g_tmp_dir_op}")
                check_arg $1 $2
                g_tmp_dir=$2
                shift
                ;;
            "--only_for_source")
                g_only_for_source=1
                g_extra_help_text="--without-devmon         : Do not install devmon.\n--with-docker         : Install docker. "
                ;;
            "${g_no_user_op}")
                g_install_user=0
                ;;
            "${g_no_kernel_op}")
                g_install_kernel=0
                ;;
            "${g_oem_install_op}")
                g_oem_install=1
                ;;
            "${g_pcap_install_op}")
                g_pcap_install=1
                ;;
            "${g_rebuild_srpm_op}")
                g_rebuild_srpm=1
                ;;
            "${g_out_dir_rebuild_op}")
                check_arg $1 $2
                if [ -d "$2" ]; then
                    g_out_dir=$2
                    shift
                else
                    echo  "-E- Path you provided does not exist"
                    exit 1
                fi
                ;;
            "${g_autocomplete_install_op}")
                g_autocomplete_install=0
                ;;
            *)
            echo "-E- Bad switch \"$1\""
            print_help
            exit 1
        esac

        shift
    done
}


function pkg_is_installed () {
    package_name=$1
    use_regex=$2
    if [ ${use_regex} == 1 ]; then
        ${g_is_all_installed_cmd} | grep ${package_name} &> /dev/null
    else
        ${g_is_installed_cmd} ${package_name} &> /dev/null
    fi
    return $?
}

function pre_packages_check () {
    missingPackages=()
    for pkg in ${g_dep_pkg_list[@]}; do
        useregex=0
        if [ $pkg == librpmbuild ]; then
            useregex=1
        fi
        pkg_is_installed $pkg $useregex; RC=$?
        if [ "${RC}" != "0" ]; then
        # Add missing package to the missing packages list
            missingPackages+=($pkg)
        fi
    done
    # Check if the current kernel sources is missing,
    # Check /lib/modules/${g_kernel_version}/build/scripts directory.
    # If not exist, report it as missing ${g_dep_kernel_source_pkg_list}
    if [ ${g_install_kernel} == "1" ]; then
        if [ -n "$MST_KERNEL_HEADER_PATH" ]; then
            if ! [ -d "$MST_KERNEL_HEADER_PATH/build/scripts" ]; then
                missingPackages+=(${g_dep_kernel_source_pkg_list})
            fi
        else
            if ! [ -d "/lib/modules/${g_kernel_version}/build/scripts" ]; then
                missingPackages+=(${g_dep_kernel_source_pkg_list})
            fi
        fi
    fi

    if [ ${#missingPackages[*]} != 0 ]; then
    # if missing packages list is not empty - report errot and suggest of installation way.
        echo_error "There are missing packages that are required for installation of MFT."
        echo_info  "You can install missing packages using: ${g_dep_ins_cmd} ${missingPackages[*]}"
        exit 1
    fi
}

function check_pkgs_present() {
    while [ "$1" ]; do
        package_name=$1
        pkg_is_installed ${package_name} 0; RC=$?
        if [ "${RC}" == "0" ]; then
            echo_warning "Failed to remove the package \"${package_name}\", try to remove it manually."
        fi
        shift
    done
}

function cleanup_pkgs () {
    existing_packages=""
    # Preapre a list of the existing packages
    while [ "$1" ]; do
        package_name=$1
        pkg_is_installed ${package_name} 0; RC=$?
        if [ "${RC}" == "0" ]; then
            existing_packages="${existing_packages} ${package_name}"
        fi
        shift
    done
    # Uninstall the packages
    if [ "${existing_packages}" != "" ]; then
        echo_info "Removing the packages: $existing_packages..."
        ${g_uninstall_cmd} ${existing_packages} &> /dev/null;
        ${g_purge_cmd} ${existing_packages} &> /dev/null;
        # Check if the uninstallation operation passed
        check_pkgs_present ${existing_packages}
    fi

}

function get_uninstaller() {
    echo `${g_list_files_cmd} ${g_mft_user} 2>&1 /dev/null | grep mft_uninstall.sh`
}

function cleanup_old_mft () {
    echo_info "Removing any old MFT file if exists..."
    ${g_package_orig_dir}/old-mft-uninstall.sh --force >& /dev/null

    # If mft-3.5.0-1 or below is installed, "/etc/mft/mstdump_dbs" will not be removed when MFT is uninstalled (its content will,
    # however). So if it exist we remove it manually
    mft_remnant_dirs="/etc/mft/mstdump_dbs"
    for dir in $mft_remnant_dirs; do
        rmdir  "$dir" > /dev/null 2>&1
    done

}

function cleanup_new_mft () {
    # Prepare the MFT package list.
    rpm_packages_list=""
    if [ "${g_mft_user}" != "${g_old_mft_package}" ]; then
        rpm_packages_list="$rpm_packages_list ${g_old_mft_package}"
    fi
    if [ "$g_install_user" == "1" ]; then
        rpm_packages_list="$rpm_packages_list ${g_mft_user}"
    fi
    if [ "$g_install_kernel" == "1" ]; then
        kernel_rpms=`rpm -qa | grep kernel-mft` # Get all kernel-mft rpms (names can vary since machines that suuprot KMP uses different rpms)
        rpm_packages_list="$rpm_packages_list ${kernel_rpms} "
    fi
    cleanup_pkgs ${rpm_packages_list}
}

function uninstall_mft() {
    uninstaller=$1
    if [[ -f ${uninstaller} ]] ; then
        no_user_op=""
        no_kernel_op=""
        if [ $g_install_user == 0 ]; then
            no_user_op="--no-user"
        fi
        if [ $g_install_kernel == 0 ]; then
            no_kernel_op="--no-kernel"
        fi
        ${uninstaller} --force ${no_user_op} ${no_kernel_op}
        rc=$?
        # Retry on failure to support backward compatibility where --no-user/--no-kernel are not supported
        if [ ${rc} != 0 ] && [ "${no_user_op}" != "" ]; then
            echo_warning "MFT user modules will be removed"
            ${uninstaller} --force ${no_kernel_op}
        fi
        if [ ${rc} != 0 ] && [ "${no_kernel_op}" != "" ]; then
            echo_warning "MFT Kernel will be removed"
            ${uninstaller} --force
        fi
        if [ ${rc} != 0 ]; then
            $(dirname "$0")/uninstall.sh > /dev/null 2>&1 || true
        fi
    fi
}

function cleanup_previous_mft_installation() {
    # Remove existing MFT temp directory
    safe_rm_rf ${g_tmp_dir}
    uninstaller="`get_uninstaller`"
    if [[ -f ${uninstaller} ]] ; then
        uninstall_mft ${uninstaller}
    else
        # PPC64 support #
        if [ ${g_machine_name} == "ppc64" ]; then
            uninstaller=echo `${g_list_files_cmd} mft-ppc64_trg 2>&1 /dev/null | grep mft_uninstall.sh`
            uninstall_mft ${uninstaller}
        fi
        #################
        if [[ ${g_package_type} == "rpm" ]]; then
            # Cleanup the new MFT RPMS if exist
            cleanup_new_mft
            # Clean any old MFT installation which may have been installed without using the RPMs
            cleanup_old_mft
        else # Ubuntu
            echo_info "Removing mft external packages installed on the machine"

            # Prepare the MFT package list.
            deb_packages_list=""
            if [ "$g_install_user" == "1" ]; then
                deb_packages_list="$deb_packages_list mft"
            fi
            if [ "$g_install_kernel" == "1" ]; then
                deb_packages_list="$deb_packages_list kernel-mft-dkms kernel-mft-modules"
            fi
            cleanup_pkgs ${deb_packages_list}
        fi

        cleanup_pkgs ${g_mft_oem} ${g_pcap}
    fi

    # Removing kernel rpm/deb is not done by the uninstaller, thus must be done explicitly
    if [ "$g_install_kernel" == "1" ]; then
        if [[ ${g_package_type} == "rpm" ]]; then
            kernel_rpms=`rpm -qa | grep kernel-mft` # Get all kernel-mft rpms (names can vary since machines that suuprot KMP uses different rpms)
        else
            kernel_rpms="kernel-mft-dkms"
        fi
            cleanup_pkgs ${kernel_rpms}
    fi
}

function install_kernel_rpm() {
    kernel_src_rpm="$1"
    kernel_rpm_dir="${g_tmp_dir}/topdir"
    rpm_arch=`rpm --eval %{_target_cpu}`
    rpm_dir="${kernel_rpm_dir}"/RPMS/"${rpm_arch}"
    build_log="${g_tmp_dir}/rpm_build.log"

    echo_debug "Kernel source RPM package is: ${kernel_src_rpm}"

    mkdir -p "${kernel_rpm_dir}"/{SPECS,SOURCES,RPMS,BUILD,SRPMS}
    # cp ${kernel_src_rpm}  ${srpm_dir}

    echo_info "Building the MFT kernel binary RPM..."
    rpmbuild $g_build_flag --define "_topdir ${kernel_rpm_dir}" --define "version ${g_mft_version}" --rebuild "${kernel_src_rpm}" >& ${build_log}; rc=$?
    if [ "$rc" !=  "0" ]; then
        echo_error   "Failed to build the kernel MFT binary RPM from the sources RPM. For more details, see ${build_log}"
        exit 1
    fi

    cd ${rpm_dir}
    # TODO: Move this code to another function
    echo_info "Installing the MFT RPMs..."

    kernel_rpm=`ls ${g_mft_kernel}-${g_mft_version}* | grep -v "debug-info"`
    install_pkg "${kernel_rpm}" "${g_tmp_dir}"
    cd - &> /dev/null
}

function rebuild_kernel_rpm() {
    kernel_src_rpm="$1"
    kernel_rpm_dir="${g_tmp_dir}/topdir"
    rpm_arch=`rpm --eval %{_target_cpu}`
    rpm_dir="${kernel_rpm_dir}"/RPMS/"${rpm_arch}"
    build_log="${g_tmp_dir}/rpm_build.log"

    echo_debug "Kernel source RPM package is: ${kernel_src_rpm}"

    mkdir -p "${kernel_rpm_dir}"/{SPECS,SOURCES,RPMS,BUILD,SRPMS}
    # cp ${kernel_src_rpm}  ${srpm_dir}

    echo_info "Building the MFT kernel binary RPM..."
    rpmbuild $g_build_flag --define "_topdir ${kernel_rpm_dir}" --define "version ${g_mft_version}" --rebuild "${kernel_src_rpm}" >& ${build_log}; rc=$?
    if [ "$rc" !=  "0" ]; then
        echo_error   "Failed to build the kernel MFT binary RPM from the sources RPM. For more details, see ${build_log}"
        exit 1
    fi

    cd ${rpm_dir}
    echo "-I- Exporting the kernel rpm ... "
    kernel_rpm=`ls ${g_mft_kernel}-${g_mft_version}* | grep -v "debug-info"`
    cp "${kernel_rpm}" "${g_out_dir}"
    echo "-I- Wrote: ${g_out_dir}/$(basename "${kernel_rpm}")"
    cd - &> /dev/null
}

function install_pkg() {
    package=$1
    tmp_dir=$2
    install_flags=$3
    file_name="${package##*/}"
    log_file=${tmp_dir}/install_${file_name}.log
    if [[ ${g_package_type} == "rpm" ]]; then
        ${g_install_cmd} $g_install_flag ${install_flags} "${package}" 2> ${log_file};   rc=$?
    else
        echo_info "Installing package: ${package}"
        ${g_install_cmd} "${package}" 2> ${log_file} 1> ${log_file};   rc=$?
    fi

    # For kernel package for debian, check if the installation passed (rc sometimes is 0 even if it fails)
    if [[ $package == *kernel* ]]; then
        grep "Module build for the currently running kernel was skipped\|Error" ${log_file} > /dev/null
        if [ "$?" == "0" ]; then
            rc=1
        fi
    fi

    if [ "$g_skip_pkg_inst_failure" == "false" ] ; then
        if [ "$rc" != "0" ]; then
            # Check if the error refer to no space left.
            no_space_err=`grep "installing package .* needs .* on the .* filesystem" "$log_file" | xargs`
            if ! [ -z "$no_space_err" ]; then
                echo_error "Installation failed. not enough space: ${no_space_err}."
                exit 1
            fi
            echo_error "Failed to install package \"${package}\"', for more details see ${log_file}"
            exit 1
        fi
    fi
}

# Install_pkgs: Intsall the needed packages according to the user options and machine info.
function Install_pkgs () {
    pkg_dir=${g_package_orig_dir}/${g_pkg_dir_name}
    spkg_dir=${g_package_orig_dir}/S${g_pkg_dir_name}

    # Update the packages path
    if [[ ${g_package_type} == "rpm" ]]; then
        user_pkg=${pkg_dir}/${g_mft_user}-${g_mft_version}-${g_mft_rel}.${g_pckg_suffix}.${g_package_type}
        oem_pkg=${pkg_dir}/${g_mft_oem}-${g_mft_version}-${g_mft_rel}.${g_pckg_suffix}.${g_package_type}
        pcap_pkg=${pkg_dir}/${g_pcap}-${g_mft_version}-${g_mft_rel}.${g_pckg_suffix}.${g_package_type}
        autocomplete_pkg=${pkg_dir}/${g_autocomplete}-${g_mft_version}-${g_mft_rel}.${g_pckg_suffix}.${g_package_type}
        kernel_src_pkg=${spkg_dir}/${g_mft_kernel}-${g_mft_version}-${g_mft_rel}.src.rpm
    else # ${g_package_type} == "deb"
        user_pkg=${pkg_dir}/${g_mft_user}_${g_mft_version}-${g_mft_rel}_${g_pckg_suffix}.${g_package_type}
        oem_pkg=${pkg_dir}/${g_mft_oem}_${g_mft_version}-${g_mft_rel}_${g_pckg_suffix}.${g_package_type}
        pcap_pkg=${pkg_dir}/${g_pcap}_${g_mft_version}-${g_mft_rel}_${g_pckg_suffix}.${g_package_type}
        autocomplete_pkg=${pkg_dir}/${g_autocomplete}_${g_mft_version}-${g_mft_rel}_${g_pckg_suffix}.${g_package_type}
        kernel_src_pkg=${spkg_dir}/${g_mft_kernel_dkms}_${g_mft_version}-${g_mft_rel}_all.deb
    fi

    # Install kernel package
    if [ "$g_install_kernel" == "1" ]; then
        if [[ ${g_package_type} == "rpm" ]]; then
            install_kernel_rpm "${kernel_src_pkg}"
        else
            install_pkg "${kernel_src_pkg}" "${g_tmp_dir}"
        fi
    fi

    # Install user package
    if [ "$g_install_user" == "1" ]; then
        if [ "${g_prefix}" != "" ]; then
            # This block can be entered only in rpm since the --prefix option is disallowed in Ubuntu
            export MFT_NEW_PREFIX_ENV=${g_prefix}
            install_pkg "${user_pkg}" "${g_tmp_dir}" "--relocate /usr=${g_prefix}"
        else
            unset MFT_NEW_PREFIX_ENV
            install_pkg "${user_pkg}" "${g_tmp_dir}"
        fi
    fi

    # Install OEM package
    if [ "${g_oem_install}" == "1" ]; then
        if [ "${g_prefix}" != "" ]; then
            # This block can be entered only in rpm since the --prefix option is disallowed in Ubuntu
            export MFT_NEW_PREFIX_ENV=${g_prefix}
            install_pkg "${oem_pkg}" "${g_tmp_dir}" "--relocate /usr=${g_prefix}"
        else
            unset MFT_NEW_PREFIX_ENV
            install_pkg "${oem_pkg}" "${g_tmp_dir}"
        fi
    fi

    # Install PCAP package
    if [ "${g_pcap_install}" == "1" ]; then
        if [ "${g_prefix}" != "" ]; then
            # This block can be entered only in rpm since the --prefix option is disallowed in Ubuntu
            export MFT_NEW_PREFIX_ENV=${g_prefix}
            install_pkg "${pcap_pkg}" "${g_tmp_dir}" "--relocate /usr=${g_prefix}"
        else
            unset MFT_NEW_PREFIX_ENV
            install_pkg "${pcap_pkg}" "${g_tmp_dir}"
        fi
    fi

    # Install autocomplete package
    if [ "${g_autocomplete_install}" == "1" ]; then
        if [ "${g_prefix}" != "" ]; then
            # This block can be entered only in rpm since the --prefix option is disallowed in Ubuntu
            export MFT_NEW_PREFIX_ENV=${g_prefix}
            install_pkg "${autocomplete_pkg}" "${g_tmp_dir}" "--relocate /usr=${g_prefix}"
        else
            unset MFT_NEW_PREFIX_ENV
            install_pkg "${autocomplete_pkg}" "${g_tmp_dir}"
        fi
    fi

}

function cleanup_residues() {
    safe_rm_rf "${g_tmp_dir}"
}
function update_machine_name() {
    if [ "$g_machine_name" == "i586" ] || [ "$g_machine_name" == "i386" ] || [ "$g_machine_name" == "i486" ] || [ "$g_machine_name" == "i686" ]; then
            g_machine_name="x86"
            if [ $g_package_type = "rpm" ]; then
                g_pckg_suffix=${g_machine_name}
            fi
    fi
}

function installation_init () {
    mkdir -p "${g_tmp_dir}"
}

# Only root can install this package.
if [ $UID != 0 ]; then
    echo_error "You must be root to install MFT"
    exit 1
fi

# Get user options.
get_user_options $@

# Check user options consistency
# --prefix option is not allowed in ubuntu
if [[ ${g_package_type} == "deb" ]] && [[ "${g_prefix}" != "" ]]; then
    echo_error "${g_pref_op} option is not supported in Ubuntu/Debian."
    exit 1
fi

# Check dependencies
if [ ${g_install_kernel} == "1" ]; then
    g_dep_pkg_list=("${g_dep_pkg_list[@]}" $g_dep_kernel_pkg_list)
fi
pre_packages_check

# Update the machine name
update_machine_name

if [ ${g_only_for_source} == "1" ]; then
    return 0
fi

#Check if need to rebuild SRPM
if [ "${g_rebuild_srpm}" == "1" ]; then
    spkg_dir=${g_package_orig_dir}/S${g_pkg_dir_name}
    if [[ ${g_package_type} == "rpm" ]]; then
        kernel_src_pkg=${spkg_dir}/${g_mft_kernel}-${g_mft_version}-${g_mft_rel}.src.rpm
    else # ${g_package_type} == "deb"
        echo_error "Ubuntu/Debian does not support this option."
        exit 1
    fi
    rebuild_kernel_rpm "${kernel_src_pkg}"
    exit 0
fi

# Cleanup existing MFT installation (Old or new) and old istallation tmp_dir
cleanup_previous_mft_installation

# Create needed folders or init
installation_init

# Install the package according to the machine setup, os and the user given flags.
Install_pkgs

# Cleaup this build residues
cleanup_residues

# Inform the user how to start mst
echo_info "In order to start mst, please run \"mst start\"."
