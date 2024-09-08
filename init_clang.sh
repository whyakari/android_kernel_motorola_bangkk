#!/bin/bash

check_and_install() {
  if ! command -v "$1" &> /dev/null; then
    echo "Error: $1 not found! Installing..."
    sudo apt update
    sudo apt install -y "$2"
  else
    echo "$1: yes"
  fi
}

mkdir -p toolchain
cd toolchain

echo 'Checking for system requirements...'

check_and_install "zstd" "zstd"
check_and_install "bsdtar" "libarchive-tools"
check_and_install "wget" "wget"

echo 'Download antman and sync'
bash <(curl -s "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman") -S=11032023 # sync neutron clang 17

echo 'Patch for glibc'
bash <(curl -s "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman") --patch=glibc

echo 'Done'

