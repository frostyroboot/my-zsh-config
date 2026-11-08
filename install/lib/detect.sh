#!/usr/bin/env bash
# install/lib/detect.sh
# Detección de sistema operativo, distribución, gestor de paquetes y arquitectura.
# Pensado para ser sourced por install/install.sh.

# Variables globales exportadas por este módulo.
: "${DETECTED_OS:=}"
: "${DETECTED_DISTRO:=}"
: "${DETECTED_PM:=}"
: "${DETECTED_ARCH:=}"
: "${DETECTED_TERMUX:=0}"

detect_arch() {
    local arch
    arch="$(uname -m 2>/dev/null || echo unknown)"
    case "$arch" in
        x86_64|amd64)   echo "x86_64" ;;
        aarch64|arm64)  echo "aarch64" ;;
        armv7l|armhf)   echo "armv7" ;;
        i386|i686)      echo "i686" ;;
        *)              echo "$arch" ;;
    esac
}

is_termux() {
    if [[ -n "${TERMUX_VERSION:-}" ]]; then
        return 0
    fi
    if [[ -d "/data/data/com.termux" ]]; then
        return 0
    fi
    if [[ -n "${PREFIX:-}" && "$PREFIX" == *"/com.termux/"* ]]; then
        return 0
    fi
    if command -v pkg >/dev/null 2>&1 && [[ -d "${PREFIX:-/data/data/com.termux/files/usr}" ]]; then
        return 0
    fi
    return 1
}

detect_os() {
    if is_termux; then
        echo "termux"
        return
    fi
    case "$(uname -s 2>/dev/null)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "macos" ;;
        *)       echo "unknown" ;;
    esac
}

detect_distro() {
    if is_termux; then
        echo "termux"
        return
    fi
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "${ID:-unknown}"
        return
    fi
    if [[ -r /etc/lsb-release ]]; then
        # shellcheck disable=SC1091
        . /etc/lsb-release
        echo "${DISTRIB_ID:-unknown}" | tr '[:upper:]' '[:lower:]'
        return
    fi
    echo "unknown"
}

detect_pm() {
    if is_termux; then
        echo "pkg"
        return
    fi
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
        return
    fi
    if command -v dnf >/dev/null 2>&1; then
        echo "dnf"
        return
    fi
    if command -v pacman >/dev/null 2>&1; then
        echo "pacman"
        return
    fi
    if command -v zypper >/dev/null 2>&1; then
        echo "zypper"
        return
    fi
    if command -v brew >/dev/null 2>&1; then
        echo "brew"
        return
    fi
    echo "unknown"
}

detect_all() {
    DETECTED_OS="$(detect_os)"
    DETECTED_DISTRO="$(detect_distro)"
    DETECTED_PM="$(detect_pm)"
    DETECTED_ARCH="$(detect_arch)"
    if is_termux; then
        DETECTED_TERMUX=1
    else
        DETECTED_TERMUX=0
    fi
    export DETECTED_OS DETECTED_DISTRO DETECTED_PM DETECTED_ARCH DETECTED_TERMUX
}

# Auto-detect al ser sourced (permite uso directo).
detect_all