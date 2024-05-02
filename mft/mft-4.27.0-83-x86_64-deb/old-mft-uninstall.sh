#!/bin/bash
#
# This software is available to you under a choice of one of two
# licenses.  You may choose to be licensed under the terms of the GNU
# General Public License (GPL) Version 2, available at
# <http://www.fsf.org/copyleft/gpl.html>, or the OpenIB.org BSD
# license, available in the LICENSE.TXT file accompanying this
# software.  These details are also available at
# <http://openib.org/license.html>.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# Copyright (c) 2009 Mellanox Technologies Ltd.  All rights reserved.
#

# pointing to the dir where this install script resides
PACKAGE_ORIG_DIR=`cd ${0%*/*};pwd`

########################################################################
#
# FUNCTIONS:
#

#Report: if uninstall failed
function uinstall_failed() {
   echo "Uninstall failed ! (see $UNINSTLOG for details)"
   exit 1
}


# Make sure no importand dirs are deleted by accident ...
function safe_rm_rf() {
    dir=$1
    case ${dir//\//} in
   usr|usrlocal|opt|bin|etc|lib|lib64|local|misc|sbin|var|boot|root|""|tmp)
   echo "-E- Tried to remove directory $dir. Deletion aborted. Make sure the right destination paths were given"
   return 1
   ;;
        *)
        /bin/rm -rf ${dir}
        ;;
    esac

    return 0
}

# Argument: the yes/no question to ask
# Returns:  1 if user answered y|yes|YES ... or if FORCE_INSTALLATION
#           0 if user answered n|NO|...
function ask_user() {
    echo -n "$1 :(y/n) [n] "
    if [ $FORCE_INST != 0 ]; then
        ans="y"
   echo $ans
    else
        read ans
    fi

    if    [ "x$ans" == "xy"   ] \
       || [ "x$ans" == "xyes" ] \
       || [ "x$ans" == "xY"   ] \
       || [ "x$ans" == "xYES" ] ; then

        ret=1
    else
        ret=0
    fi

    return $ret
}


function cleanup_mft_files() {
    # Clean old distribution
    binApps="mlxburn aimage mic spark ibspark flint t2a uninstall_mft.sh"

    local logFile="$1"

    echo "  Removing Executables from : ........ ${CONFIG_ROOT}/bin."
    for f in $binApps; do
        rm -f ${CONFIG_ROOT}/bin/$f 2>&1 > /dev/null;
        if [ $? == 0 ]; then
            echo "Removed : ${CONFIG_ROOT}/bin/$f" >> $logFile
        fi
    done

    echo "  Removing MFT Man Pages from : ...... /usr/share/man/man1."
    mans="mlxburn flint spark"
    for f in $mans; do
        rm -r /usr/share/man/man1/$f.1.* 2>&1 > /dev/null;
        if [ $? == 0 ]; then
            echo "Removed : " /usr/share/man/man1/$f.1.* >> $logFile
        fi
    done

    libs=${CONFIG_ROOT}/lib/mft
    echo "  Removing MFT libs from : ........... $libs"
    safe_rm_rf $libs 2>&1 > /dev/null;
    if [ $? == 0 ]; then
        echo "Removed : " $libs >> $logFile
    fi

    echo "  Removing MFT directory: ............ $MFTHOME"
    safe_rm_rf $MFTHOME 2>&1 > /dev/null;
    if [ $? == 0 ]; then
        echo "Removed : " $MFTHOME >> $logFile
    fi

    echo "  Removing installation info file: ... $INFO"
    rm -f $INFO
    if [ $? == 0 ]; then
        echo "Removed : " $INFO >> $logFile
    fi
}


function init_data_from_info() {
    # source the file:
    . $INFO

    # Check params:
    # INFO_INSTALL_DATE
    # INFO_MFTHOME
    # INFO_FINAL_PREFIX
    # INFO_BLD_ID

    local err_msg="Corrupted installation info file ($INFO)"
    if [ -z $INFO_MFTHOME ]; then
        echo "-E- $err_msg: MFTHOME is not defined."
        return 1
    else
        MFTHOME=$INFO_MFTHOME
    fi

    if [ -z $INFO_FINAL_PREFIX ]; then
        echo "-E- $err_msg: FINAL_PREFIX is not defined."
        return 1
    else
        FINAL_PREFIX=$INFO_FINAL_PREFIX
        CONFIG_ROOT=$INFO_FINAL_PREFIX
    fi

    if [ -z $INFO_INSTALL_MST ]; then
        echo "-E- $err_msg: INFO_INSTALL_MST is not defined."
        return 1
    else
        REMOVE_MST=$INFO_INSTALL_MST
    fi

    # Check that MFTHOME exists:
    if [ ! -d $MFTHOME ]; then
        echo "-E- $err_msg: Instalation directory ($MFTHOME) defined in this file does not exist."
        return 1
    fi

    # success
    return 0
}
function update_default_info () {
    echo "-I- Removing the default MFT dirs and files"
    MFTHOME="/usr/mellanox/mft"
    FINAL_PREFIX="/usr"
    CONFIG_ROOT=$FINAL_PREFIX
    REMOVE_MST="1"
}

function remove_mst() {
    MST_DIR="/usr/mst"
    BIN_DIR="/usr/bin"
    MST_BIN="$MST_DIR/bin"
    MST_DEAMON=/etc/init.d/mst
    echo "  Removing MST directory: ............ $MST_DIR"
    rm -rf $MST_DIR

    echo "  Removing MST daemon: ............... $MST_DEAMON"
    rm -f $MST_DEAMON
    rm -f $BIN_DIR/mst

    echo "  Removing MST links from: ........... $MST_BIN"
    for link_name in $(ls -ltr $BIN_DIR | grep $MST_BIN | awk '{print $(NF-2)}'); do
       link="$BIN_DIR/$link_name"
       rm -f $link
    done


}



########################################################################

PLATF=`uname -m`

case $PLATF in
    "i686")
         MY_EXT="x86"
         ;;
    "ia64")
         MY_EXT="ia64"
         ;;
    "x86_64")
         MY_EXT="x86_64"
         ;;
    "ppc64")
         MY_EXT="ppc64"
         ;;
    *)
         echo "Unsupported platform ($PLATF). MFT Currently supports only x86, ia64 platforms"
         exit 1
esac

usage()
{
cat << EOF
        Usage: ${prog} [--force]
EOF
}

if [ $UID != 0 ]; then
  echo You must be root to un-install MFT
  exit 1
fi
umask 022   # assure readibility to all users

prog=`basename $0`
FORCE_INST=0
while [ ! -z "$1" ]
do
        case $1 in
                -f|--force)
                FORCE_INST=1
                shift
                ;;
                *)
                usage
                exit 1
                ;;
        esac
done


# Check info file
INFO=/etc/mft/info


# Locate installation home and prefix
if [ -r $INFO ]; then
    init_data_from_info
    if [ $? -ne 0 ]; then
        echo "-E- File $INFO seem to be corrupted. Removing."
        rm -f $INFO
        update_default_info
    fi
else
    echo "-W- Installation info file ($INFO) not found".
    update_default_info
fi

BLD_ID="<unknown>"
if test -e ${MFTHOME}/BUILD_ID ; then
  BLD_ID=`cat $MFTHOME/BUILD_ID | grep BUILD_ID | cut -f2 -d"="`
fi

UNINSTLOG=/dev/null
CFGLOG=$UNINSTLOG
#rm -f $UNINSTLOG
echo "MFT-$MY_EXT \($BLD_ID\) uninstalled on `date`." >| $UNINSTLOG
echo "Modules uninstall log file:" >> $UNINSTLOG


cat<<EOF

  *** Mellanox Firmware Tools (MFT) Package Uninstall   ***
      MFT Build $BLD_ID

  Copyright (C) Oct  2009, Mellanox Technologies  Ltd.
  ALL  RIGHTS  RESERVED.   Use of  software subject to the
  terms and conditions detailed in the file "LICENSE.txt".

EOF




# Check for previous installations
echo "  This program un-installs Mellanox Firmware Tools (MFT) package."
echo "  Current installed MFT Build ID is $BLD_ID" | tee -a $UNINSTLOG

echo "" >> $UNINSTLOG
ask_user "  Remove currently installed components ? "
if [ $? -ne 0 ] ; then
    cleanup_mft_files $UNINSTLOG
else
    echo Aborting
    exit 1
fi
if [ "$REMOVE_MST" == "1" ]; then
    remove_mst
fi



echo "  " | tee -a $UNINSTLOG
echo "  ---------------------------------- " | tee -a $UNINSTLOG
echo "     MFT un-installation done."        | tee -a $UNINSTLOG
echo "  ---------------------------------- " | tee -a $UNINSTLOG
echo "  "

exit 0
