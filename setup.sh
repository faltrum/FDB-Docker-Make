#!/usr/bin/env sh
set -eu

log() {
  printf '%s\n' "[setup] $*"
}

warn() {
  printf '%s\n' "[setup][warn] $*" >&2
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif has_cmd sudo; then
    sudo "$@"
  else
    "$@"
  fi
}

os_name() {
  uname -s 2>/dev/null || echo unknown
}

is_wsl() {
  [ -n "${WSL_DISTRO_NAME:-}" ] && return 0
  [ -n "${WSL_INTEROP:-}" ] && return 0
  [ -r /proc/version ] && grep -qi microsoft /proc/version && return 0
  return 1
}

install_linux_make() {
  if has_cmd apt-get; then
    run_sudo apt-get update
    run_sudo apt-get install -y make curl ca-certificates
  elif has_cmd dnf; then
    run_sudo dnf install -y make curl ca-certificates
  elif has_cmd yum; then
    run_sudo yum install -y make curl ca-certificates
  elif has_cmd pacman; then
    run_sudo pacman -Sy --noconfirm make curl ca-certificates
  elif has_cmd zypper; then
    run_sudo zypper --non-interactive install make curl ca-certificates
  elif has_cmd apk; then
    run_sudo apk add --no-cache make curl ca-certificates
  else
    warn "No package manager found for Linux. Install make manually."
  fi
}

install_linux_docker() {
  if has_cmd docker; then
    return
  fi

  warn "Docker is not installed. Attempting install from distro repositories."
  if has_cmd apt-get; then
    run_sudo apt-get update
    run_sudo apt-get install -y docker.io docker-compose-plugin
  elif has_cmd dnf; then
    run_sudo dnf install -y docker docker-compose-plugin
  elif has_cmd yum; then
    run_sudo yum install -y docker docker-compose-plugin
  elif has_cmd pacman; then
    run_sudo pacman -Sy --noconfirm docker docker-compose
  elif has_cmd zypper; then
    run_sudo zypper --non-interactive install docker docker-compose
  elif has_cmd apk; then
    run_sudo apk add --no-cache docker docker-cli-compose
  else
    warn "Could not install Docker automatically."
  fi
}

install_macos_deps() {
  if ! has_cmd brew; then
    warn "Homebrew is required on macOS. Install it first: https://brew.sh"
    return
  fi

  if ! has_cmd make; then
    brew install make
  fi

  if ! has_cmd docker; then
    warn "Installing Docker Desktop via Homebrew cask."
    brew install --cask docker
  fi
}

run_powershell() {
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$1"
}

install_windows_make() {
  if has_cmd make; then
    return
  fi

  if has_cmd winget; then
    log "Installing make via winget (ezwinports.make, fallback GnuWin32.Make)."
    run_powershell "winget install -e --id ezwinports.make --accept-source-agreements --accept-package-agreements" || true
    has_cmd make && return
    run_powershell "winget install -e --id GnuWin32.Make --accept-source-agreements --accept-package-agreements" || true
  fi

  if has_cmd choco && ! has_cmd make; then
    log "Installing make via chocolatey."
    run_powershell "choco install -y make" || true
  fi

  if has_cmd scoop && ! has_cmd make; then
    log "Installing make via scoop."
    run_powershell "scoop install make" || true
  fi
}

install_windows_docker() {
  if has_cmd docker; then
    return
  fi

  if has_cmd winget; then
    log "Installing Docker Desktop via winget."
    run_powershell "winget install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements" || true
    return
  fi

  if has_cmd choco; then
    log "Installing Docker Desktop via chocolatey."
    run_powershell "choco install -y docker-desktop" || true
    return
  fi

  warn "Could not install Docker Desktop automatically on Windows."
}

verify_deps() {
  missing=0

  if has_cmd make; then
    log "OK: make found ($(command -v make))."
  else
    warn "Missing: make"
    missing=1
  fi

  if has_cmd docker; then
    log "OK: docker found ($(command -v docker))."
  else
    warn "Missing: docker"
    missing=1
  fi

  if has_cmd docker && docker compose version >/dev/null 2>&1; then
    log "OK: docker compose plugin available."
  else
    warn "Missing: docker compose plugin"
    missing=1
  fi

  if [ "$missing" -ne 0 ]; then
    warn "Some dependencies are still missing. Open a new terminal and rerun ./setup.sh after installations complete."
    return 1
  fi

  return 0
}

main() {
  os="$(os_name)"
  target="${SETUP_TARGET:-auto}"

  if [ "$target" != "auto" ] && [ "$target" != "current" ] && [ "$target" != "windows-host" ]; then
    warn "Invalid SETUP_TARGET='$target'. Use: auto, current, windows-host"
    exit 1
  fi

  if is_wsl; then
    log "Detected runtime OS: $os (WSL on Windows host)"
    log "Tip: use SETUP_TARGET=windows-host to install tools in Windows instead of WSL."
  else
    log "Detected runtime OS: $os"
  fi

  if [ "$target" = "auto" ]; then
    target="current"
  fi

  if [ "$target" = "windows-host" ]; then
    if has_cmd powershell.exe; then
      log "Installing on Windows host via powershell.exe"
      install_windows_make
      install_windows_docker
      log "Windows host install flow finished."
      log "Open a new PowerShell terminal and check: make --version, docker --version"
      return
    fi

    warn "powershell.exe not available from this shell; cannot target Windows host."
    exit 1
  fi

  case "$os" in
    Linux*)
      install_linux_make
      install_linux_docker
      ;;
    Darwin*)
      install_macos_deps
      ;;
    CYGWIN*|MINGW*|MSYS*)
      install_windows_make
      install_windows_docker
      ;;
    *)
      warn "Unsupported OS: $os"
      ;;
  esac

  if verify_deps; then
    log "Setup completed. You can now use: make help"
  else
    exit 1
  fi
}

main "$@"
