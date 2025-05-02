#!/bin/bash
#by Akina | LuoYan
#2024-06-03 Rewrite
#shellcheck disable=SC2059,SC2086,SC2166

# TODO:
# - None

# Check if debug mode is enabled via the APTOOLDEBUG environment variable
if [ -n "${APTOOLDEBUG}" ]; then
    if [ ${APTOOLDEBUG} -eq 1 ]; then
        printf "\033[1;33m[WARN] $(date "+%H:%M:%S"): Debug mode is on.\033[0m\n"
        set -x # Enable command tracing
    fi
fi
# Color variables for formatted output
RED="\033[1;31m"    # RED
YELLOW="\033[1;33m" # YELLOW
BLUE="\033[40;34m"  # BLUE
RESET="\033[0m"     # RESET

# Formatted print for informational messages
msg_info() {
    printf "${BLUE}[INFO] $(date "+%H:%M:%S"): ${1}${RESET}\n"
}
# Formatted print for warning messages
msg_warn() {
    printf "${YELLOW}[WARN] $(date "+%H:%M:%S"): ${1}${RESET}\n"
}
# Formatted print for error messages
msg_err() {
    printf "${RED}[ERROR] $(date "+%H:%M:%S"): ${1}${RESET}\n"
}
# Formatted print for fatal error messages
msg_fatal() {
    printf "${RED}[FATAL] $(date "+%H:%M:%S"): ${1}${RESET}\n"
}
# Check the operating system type
if command -v getprop >/dev/null 2>&1; then
    OS="android"
else
    OS="linux"
fi
# Function to print help message and exit
print_help() {
    printf "${BLUE}%s${RESET}\n\n" "
APatch Auto Patch Tool
Written by Akina
Version: 7.0.0
Current DIR: $(pwd)

-h, -v,                 print the usage and version.
-i PATH/TO/IMAGE,       specify a boot image path.
-k [RELEASE NAME],      specify a kernelpatch version [RELEASE NAME].
-d PATH/TO/DIR,         specify a folder containing AAPFunction, kptools and kpimg that we need.
-s \"STRING\",            specify a superkey. Use STRING as superkey.
-A [PATH],                     Download latest APatch CI build to PATH.
-K,                     Specify the KPMs to be embedded.
-I,                     directly install to current slot after patch.
-S,                     Install to another slot (for OTA).
-E [ARGS],              Add args [ARGS] to kptools when patching.
-c [COMMANDS],          Specifies extra commands to run (developers only)."
    TWIDTH=$(tput cols)
    TEXTLEN=4
    MIDPOS=$(((TWIDTH - TEXTLEN) / 2))
    printf "${BLUE}%*s${RESET}\n" $MIDPOS "NOTE"
    printf "${BLUE}%s${RESET}\n" "When arg -I is not specified, the patched boot image will be stored in /storage/emulated/0/patched_boot.img(on android) or \${HOME}/patched_boot.img(on linux).

When the -s parameter is not specified, uuid will be used to generate an 8-digit SuperKey that is a mixture of alphanumeric characters.

When the -d parameter is specified, the specified folder should contain AAPFunction, magiskboot, kptools and kpimg, otherwise you will get a fatal error.

In addition, you can use \`APTOOLDEBUG=1 ${0} [ARGS]\` format to enter verbose mode.
"
    exit 0
}

# Analyze command line arguments
DOWNFILES=true # Flag to indicate if files should be downloaded
while getopts ":hA:vi:k:KIVs:Sd:E:c:" OPT; do
    # $OPTARG holds the argument of the current option
    case $OPT in
    c)
        bash -c "$OPTARG" # Execute the provided commands
        ;;
    h | v)
        print_help # Print help message
        ;;
    A)
        DOWNLOAD_ANDROID_VER=true # Flag to download Android version
        DOWNLOAD_PATH="$(realpath ${OPTARG})" # Get the real path of the download directory
        ;;
    d)
        MISSINGFILES=0 # Counter for missing files
        WORKDIR="$(realpath ${OPTARG})" # Get the real path of the specified working directory
        if [ ! -d "${WORKDIR}" ]; then
            msg_fatal "${WORKDIR}: No such directory."
            exit 1
        fi
        # Check for required files in the specified directory
        for i in AAPFunction magiskboot kptools-${OS} kpimg-android; do
            if [ ! -e "${WORKDIR}/${i}" ]; then
                msg_fatal "Missing file: ${WORKDIR}/${i}"
                MISSINGFILES=$((MISSINGFILES + 1))
            fi
        done
        # If any required files are missing
        if [[ ${MISSINGFILES} -gt 0 ]]; then
            unset WORKDIR # Unset the working directory variable
            msg_fatal "There are ${MISSINGFILES} files missing, and we need 4 files in total. Please read the instructions in ${0} -h."
            msg_info "Omit the -d parameter; the file will be downloaded remotely."
        else
            DOWNFILES=false # Disable file download
            msg_info "The work directory was manually specified: ${WORKDIR}. AAPFunction, kptools and kpimg will not be downloaded again."
        fi
        ;;
    K)
        EMBEDKPMS=true # Flag to embed KPMs
        msg_info "The -K parameter was received. Will embed KPMs."
        ;;
    i)
        BOOTPATH="$(realpath ${OPTARG})" # Get the real path of the boot image
        if [ -e "${BOOTPATH}" ]; then
            msg_info "Boot image path specified. Current image path: ${BOOTPATH}"
            if [ ! -f "${BOOTPATH}" ]; then
                msg_fatal "${BOOTPATH}: Not a file."
                exit 1
            fi
        else
            msg_fatal "${BOOTPATH}: The file does not exist."
            exit 1
        fi
        ;;
    S)
        SAVEROOT="true" # Flag to save root (install to another slot)
        msg_info "The -S parameter was received. The patched image will be flashed into another slot if this is a ab partition device."
        ;;
    I)
        if [ "${OS}" = "android" ]; then
            INSTALL="true" # Flag to install directly
            msg_info "The -I parameter was received. Will install after patching."
        else
            msg_fatal "Do not use this arg without Android!"
            exit 1
        fi
        ;;
    s)
        SUPERKEY="${OPTARG}" # Set the superkey from the argument
        # Check password length
        if [[ ${#SUPERKEY} -lt 8 ]]; then
            msg_fatal "The SuperKey is too short! It should be at least eight characters long and contain at least two of the following: numbers, letters, and symbols."
            exit 1
        fi
        # Check for the presence of letters and numbers, letters and symbols, or numbers and symbols
        if [[ "$SUPERKEY" =~ [A-Za-z] && "$SUPERKEY" =~ [0-9] ]]; then
            ISOK=true
        elif [[ "$SUPERKEY" =~ [A-Za-z] && "$SUPERKEY" =~ [\@\#\$\%\^\&\*\(\)\_\+\!\~\-\=] ]]; then
            ISOK=true
        elif [[ "$SUPERKEY" =~ [0-9] && "$SUPERKEY" =~ [\@\#\$\%\^\&\*\(\)\_\+\!\~\-\=] ]]; then
            ISOK=true
        else
            ISOK=false
        fi
        case ${ISOK} in
        true) msg_info "Valid SuperKey. Current SuperKey: ${SUPERKEY}" ;;
        false) msg_fatal "You input a SuperKey that does not meet standards! It should be at least eight characters long and contain at least two of the following: numbers, letters, and symbols." && exit 1 ;;
        esac
        ;;
    k)
        KPTOOLVER="${OPTARG}" # Set the kptools version
        msg_info "The -k parameter was received. Will use kptool ${KPTOOLVER}."
        ;;
    E)
        EXTRAARGS="${OPTARG}" # Set extra arguments for kptools
        msg_info "The -E parameter was received. Current extra args: ${EXTRAARGS}"
        ;;
    :)
        msg_fatal "Option -${OPTARG} requires an argument.." >&2
        exit 1
        ;;

    ?)
        msg_fatal "Invalid option: -${OPTARG}" >&2
        exit 1
        ;;
    esac
done

# Check if the script is running with root privileges
if [ "$(id -u)" -eq 0 ]; then
    ROOT=true
    # Check for unsupported Magisk versions on Android
    if [ "${OS}" = "android" ]; then
        if [ "$(magisk -v | grep "delta")" -o "$(magisk -v | grep "kitsune")" ]; then
            msg_fatal "Detected Magisk Deleta/Kitsune: Unsupported environment. Aborted."
            exit 114
        fi
    fi
else
    ROOT=false
    msg_warn "You are running in unprivileged mode; some functionality may be limited."
fi
# Download latest CI build section
if [[ "${DOWNLOAD_ANDROID_VER}" == "true" ]]; then
    if [[ ! -e "${DOWNLOAD_PATH}" ]]; then
        msg_fatal "${DOWNLOAD_PATH} do not exist."
        exit 1
    fi
    msg_info "Now downloading..."
    curl -L --progress-bar "https://nightly.link/bmax121/APatch/workflows/build/main/APatch.zip" -o "${DOWNLOAD_PATH}/APatch.zip" || ES=$? # Download the zip file
    if [[ ${ES} -eq 0 ]]; then
        msg_info "Done."
        exit 0
    else
        msg_fatal "Download Failed. Check the err msg above and try again."
        exit 1
    fi
fi
# Check image path for Linux
if [ "${OS}" = "linux" -a -z "${BOOTPATH}" ]; then
    msg_fatal "You are using ${OS}, but there is no image specified by you. Aborted."
    exit 1
fi
# Check if the specified boot path is a file
if [ -e "${BOOTPATH}" -a ! -f "${BOOTPATH}" ]; then
    msg_fatal "You specified a path, but that path is not a file!"
    exit 1
fi
# Exit if no root and no boot image is specified
if [ -z "${BOOTPATH}" -a "${ROOT}" = "false" ]; then
    msg_fatal "No root and no boot image is specified. Aborted."
    exit 1
fi
# Set the working directory if not already set
if [ -z "${WORKDIR}" ]; then
    WORKDIR="$(mktemp -d)" # Create a temporary directory
fi
# Determine if the device uses A/B partitioning and set BOOTSUFFIX accordingly
if [ "${OS}" = "android" ]; then
    BYNAMEPATH=$(getprop ro.frp.pst | sed 's/\/frp//g') # Get the by-name path
    if [ ! -e "${BYNAMEPATH}/boot" ]; then
        BOOTSUFFIX=$(getprop ro.boot.slot_suffix) # Get the current boot slot suffix
    fi
else
    msg_info "Current OS is not Android. Skip boot slot check."
fi
# Determine the target slot for OTA installation
if [ -n "${SAVEROOT}" -a -n "${BOOTSUFFIX}" -a "${OS}" = "android" ]; then
    if [ "${BOOTSUFFIX}" = "_a" ]; then
        TBOOTSUFFIX="_b"
    else
        TBOOTSUFFIX="_a"
    fi
    msg_warn "You have specified the installation to another slot. Current slot:${BOOTSUFFIX}. Slot to be flashed into:${TBOOTSUFFIX}."
fi
# Generate a SuperKey using uuid if not provided
if [ -z "${SUPERKEY}" ]; then
    SUPERKEY="$(cat /proc/sys/kernel/random/uuid | cut -d \- -f1)"
fi

# Download the AAPFunction file if DOWNFILES is true
if [[ "${DOWNFILES}" == "true" ]]; then
    msg_info "Downloading function file from GitHub..."
    curl -L --progress-bar "https://raw.githubusercontent.com/AkinaAcct/APatchTool/main/AAPFunction" -o ${WORKDIR}/AAPFunction
    EXITSTATUS=$?
    if [ $EXITSTATUS != 0 ]; then
        msg_fatal "Download failed. Check your Internet connection and try again."
        exit 1
    fi
fi

# Backup the boot image if running with root on Android
msg_info "Now backing up the boot image..."
if [ "${ROOT}" == "true" ]; then
    if [ "${OS}" == "android" ]; then
        msg_info "Backing up boot image..."
        dd if=${BYNAMEPATH}/boot${BOOTSUFFIX} of=/storage/emulated/0/stock_boot${BOOTSUFFIX}.img # Backup the current boot image
        EXITSTATUS=$?
        if [ "${EXITSTATUS}" != "0" ]; then
            msg_err "Boot image backup failed."
            msg_warn "Skip backing up boot image..."
        else
            msg_info "Done. Boot image path: /storage/emulated/0/stock_boot${BOOTSUFFIX}.img"
        fi
    else
        msg_info "Currently OS in not Android; Skip backup."
    fi
else
    msg_warn "No root. Skip back up."
fi

# Load the AAPFunction script
. ${WORKDIR}/AAPFunction

# Call functions from AAPFunction to get device boot information, tools, and patch the boot image
get_device_boot
get_tools
patch_boot
# Install the patched boot image if the -I flag was used
if [ -n "${INSTALL}" ]; then
    msg_warn "The -I parameter was received. Will install patched image."
    flash_boot
else
    # Copy the patched boot image to the default location
    if [ "${OS}" = "android" ]; then
        msg_info "Now copying patched image to /storage/emulated/0/patched_boot.img..."
        mv ${WORKDIR}/new-boot.img /storage/emulated/0/patched_boot.img
    else
        msg_info "Now copying patched image to ${HOME}/patched_boot.img..."
        mv ${WORKDIR}/new-boot.img "${HOME}/patched_boot.img"
    fi
    msg_info "Done. Now deleting tmp files..."
    rm -rf ${WORKDIR} # Remove the temporary working directory
    msg_info "Done."
fi
# Print the generated or provided SuperKey
print_superkey
