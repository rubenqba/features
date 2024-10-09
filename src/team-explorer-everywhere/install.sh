#!/bin/bash
set -ex

install_deps() {
  apt update -q && apt install curl unzip jq -yq
}

# Función para agregar al PATH de diferentes shells
add_to_shell_profile() {
  local shell_profile="$1"
  local export_statement="export PATH=/opt/tee-clc/current:\$PATH"

  if [ -f "$shell_profile" ]; then
    # Si el archivo de perfil existe y no tiene ya el comando, lo añadimos
    if ! grep -q "$export_statement" "$shell_profile"; then
      echo "$export_statement" >> "$shell_profile"
      echo "Agregado a $shell_profile"
    fi
  # else
  #   # Si el archivo de perfil no existe, lo creamos con el comando
  #   echo "$export_statement" > "$shell_profile"
  #   echo "Creado $shell_profile con la configuración de PATH"
  fi
}

install_tee() {
  BASE_DIR=$1
  version=$2

  if [ ! -d "$BASE_DIR/$version" ]; then
    echo "Installing TEE CLC version $version..."
    mkdir -p "$BASE_DIR"
    curl -vLo "$BASE_DIR/tee-clc.zip" https://github.com/microsoft/team-explorer-everywhere/releases/latest/download/TEE-CLC-${version}.zip
    unzip "$BASE_DIR/tee-clc.zip" -d "$BASE_DIR"
    rm -f "$BASE_DIR/tee-clc.zip"
    ln -sf "$BASE_DIR/TEE-CLC-$version" "$BASE_DIR/current"

    # Agregar el comando 'tf' a PATH
    add_to_shell_profile "/etc/bash.bashrc"  # para Bash globalmente
    add_to_shell_profile "/etc/profile"      # para shells POSIX como sh
    # Agregar al PATH en zsh
    add_to_shell_profile "/etc/zsh/zshrc"    # para Zsh globalmente 
  else
    echo "Team Explorer Everywhere v$version is already installed"
  fi;
}

detect_latest_version() {
  VERSION=$(curl -sL https://api.github.com/repos/microsoft/team-explorer-everywhere/releases/latest | jq -r .name)
}

check_version() {
  version=$1
  result=$(curl -sL  "https://api.github.com/repos/microsoft/team-explorer-everywhere/releases/tags/$version" | jq -r .name)
  echo "check result: $result"

  [ "$result" == "null" ] && (echo "Team Explorer Everywhere v$version doesn't exists"; exit 1)
  return 0;
}

echo "Activating feature 'tee-clc'"

which curl 2> /dev/null || install_deps
which unzip 2> /dev/null || install_deps
which jq 2> /dev/null || install_deps

VERSION=${VERSION:-latest}

[ "$VERSION" == "latest" ] && detect_latest_version;
echo "The provided version is: $VERSION"

check_version "$VERSION";
echo "The verified version is: $VERSION"

INSTALL_DIR="/opt/team-explorer-everywhere"

# The 'install.sh' entrypoint script is always executed as the root user.
#
# These following environment variables are passed in by the dev container CLI.
# These may be useful in instances where the context of the final 
# remoteUser or containerUser is useful.
# For more details, see https://containers.dev/implementors/features#user-env-var
echo "The effective dev container remoteUser is '$_REMOTE_USER'"
echo "The effective dev container remoteUser's home directory is '$_REMOTE_USER_HOME'"

echo "The effective dev container containerUser is '$_CONTAINER_USER'"
echo "The effective dev container containerUser's home directory is '$_CONTAINER_USER_HOME'"

install_tee "$INSTALL_DIR" "$VERSION" 
