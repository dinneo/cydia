#!/bin/bash

set -e

shopt -s extglob
shopt -s nullglob

version=$(sw_vers -productVersion)
cpu=$(uname -p)

if [[ ${cpu} == arm ]]; then
    data=/var/lib/dpkg
    model=hw.machine
    arch=iphoneos-arm
else
    data=/Library/Cydia/dpkg
    model=hw.model
    arch=cydia
fi

model=$(sysctl -n "${model}")

status=${data}/status

function lower() {
    sed -e 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/'
}

# Generate New Package {{{
function pseudo() {
    local package=$1 version=$2 description=$3 name=$4
    echo "/." >"${data}"/info/"${package}".list

    cat <<EOF
Package: ${package}
Essential: yes
Status: install ok installed
Priority: required
Section: System
Installed-Size: 0
Architecture: ${arch}
Version: ${version}
Description: ${description}
Tag: role::cydia
EOF

    [[ -n ${name} ]] && echo "Name: ${name}"
    echo
}
# }}}

{

# Delete Old Packages {{{
    unset firmware
    unset blank

    while IFS= read -r line; do
        #echo "#${firmware+@}/${blank+@} ${line}" 1>&2

        if [[ ${line} == '' && "${blank+@}" ]]; then
            continue
        else
            unset blank
        fi

        if [[ ${line} == "Package: "@(firmware|gsc.*|cy+*) ]]; then
            firmware=
        elif [[ ${line} == '' ]]; then
            blank=
        fi

        if [[ "${firmware+@}" ]]; then
            if [[ "${blank+@}" ]]; then
                unset firmware
            fi
            continue
        fi

        #echo "${firmware+@}/${blank+@} ${line}" 1>&2
        echo "${line}"
    done <"${status}"

    #echo "#${firmware+@}/${blank+@} EOF" 1>&2
    if ! [[ "${blank+@}" || "${firmware+@}" ]]; then
        echo
    fi
# }}}

    if [[ ${cpu} == arm ]]; then
        pseudo "firmware" "${version}" "almost impressive Apple frameworks" "iOS Firmware"

        while [[ 1 ]]; do
            gssc=$(gssc 2>&1)
            if [[ ${gssc} != *'(null)'* ]]; then
                break
            fi
            sleep 1
        done

        echo "${gssc}" | sed -re '
            /^    [^ ]* = [0-9.]*;$/ ! d;
            s/^    ([^ ]*) = ([0-9.]*);$/\1 \2/;
            s/([A-Z])/-\L\1/g; s/^"([^ ]*)"/\1/;
            s/^-//;
            / 0$/ d;
        ' | while read -r name value; do
            pseudo "gsc.${name}" "${value}" "virtual GraphicsServices dependency"

            if [[ ${name} == ipad ]]; then
                pseudo "gsc.wildcat" "${value}" "virtual virtual GraphicsServices dependency"
            fi
        done
    fi

    if [[ ${cpu} == arm ]]; then
        os=ios
    else
        os=macosx
    fi

    pseudo "cy+os.${os}" "${version}" "virtual operating system dependency"
    pseudo "cy+cpu.${cpu}" "0" "virtual CPU dependency"

    name=${model%%*([0-9]),*([0-9])}
    version=${model#${name}}
    name=$(lower <<<${name})
    version=${version/,/.}
    pseudo "cy+model.${name}" "${version}" "virtual model dependency"

    pseudo "cy+kernel.$(lower <<<$(sysctl -n kern.ostype))" "$(sysctl -n kern.osrelease)" "virtual kernel dependency"

    pseudo "cy+lib.corefoundation" "$(/usr/libexec/cydia/cfversion)" "virtual corefoundation dependency"

} >"${status}"_

mv -f "${status}"{_,}

if [[ ${cpu} == arm ]]; then
    if [[ ! -h /User && -d /User ]]; then
        cp -afT /User /var/mobile
    fi && rm -rf /User && ln -s "/var/mobile" /User

    echo 5 >/var/lib/cydia/firmware.ver
fi
