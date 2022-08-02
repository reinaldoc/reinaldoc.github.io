#!/bin/bash

# openssl req -new -x509 -newkey rsa:2048 -keyout MOK.priv -outform DER -out MOK.der -nodes -days 36500 -subj "/CN=VirtualBox/"
# apt-get install mokutil
# mokutil --import MOK.der
# reboot

SIGNER=/usr/src/linux-headers-$(uname -r)/scripts/sign-file

test -x "${SIGNER}" || { echo "sign-file not found. Exiting..."; exit ;}

VBOXDRV_PATH=$(modinfo -n vboxdrv)

test -z "${VBOXDRV_PATH}" && { echo "vboxdrv module not found. Exiting..."; exit ;}

for modfile in $(dirname "${VBOXDRV_PATH}")/vbox*.ko; do
  echo "Signing $modfile"
  ${SIGNER} sha256 /root/mok/MOK.priv /root/mok/MOK.der "$modfile"
  if [ "${?}" == 0 ] ; then
    filename=${modfile##*/}
    modprobe ${filename%%.*}
  else
    echo "Error signing '${modfile##*/}'."
  fi
done
