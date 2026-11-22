#!/bin/bash

#PRINT_UELA="1"
NSIS_SCRIPT="installer.nsi"
ICON_FILE=""
DOWNLOAD_URLS=()
INSTALL_SERVICE="n"

write_eula() {
    #place holder
}

# App name
read -rp "Enter the name of your application: " APP_NAME
[[ -z "$APP_NAME" ]] && { echo "Error: Application name is required."; exit 1; }

# Determine default install dir based on architecture
read -rp "Is your build 64-bit? (y/n): " IS_64BIT
IS_64BIT=${IS_64BIT,,}
if [[ "$IS_64BIT" == "y" ]]; then
    DEFAULT_OUTDIR="C:\\Program Files\\$APP_NAME"
else
    DEFAULT_OUTDIR="C:\\Program Files (x86)\\$APP_NAME"
fi

# Ask for install directory
read -rp "Enter the installation directory for main.exe (default: $DEFAULT_OUTDIR): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-$DEFAULT_OUTDIR}

INSTALLER_EXE="${APP_NAME// /_}-Installer.exe"

# Startup
read -rp "Should the program start at boot as a regular process? (y/n): " STARTUP
STARTUP=${STARTUP,,}

# Windows Service
read -rp "Do you want to install main.exe as a Windows service? (y/n): " INSTALL_SERVICE
INSTALL_SERVICE=${INSTALL_SERVICE,,}
if [[ "$INSTALL_SERVICE" == "y" ]]; then
    read -rp "Enter the desired service name: " SERVICE_NAME
    SERVICE_NAME=${SERVICE_NAME:-$APP_NAME}
fi

# File downloads
read -rp "Should the installer download additional files? (y/n): " DOWNLOAD_FILES
DOWNLOAD_FILES=${DOWNLOAD_FILES,,}
if [[ "$DOWNLOAD_FILES" == "y" ]]; then
    while true; do
        read -rp "Enter a URL to download a file (or press Enter to finish): " FILE_URL
        [[ -z "$FILE_URL" ]] && break
        DOWNLOAD_URLS+=("$FILE_URL")
    done
fi

# Registry keys
read -rp "Should the installer add registry keys? (y/n): " ADD_REGISTRY
ADD_REGISTRY=${ADD_REGISTRY,,}

# Icon
read -rp "Do you want to use a custom icon for the installer? (y/n): " USE_ICON
USE_ICON=${USE_ICON,,}
if [[ "$USE_ICON" == "y" ]]; then
    read -rp "Enter the path to the .ico file: " ICON_FILE
    [[ ! -f "$ICON_FILE" ]] && { echo "Error: Icon file not found!"; exit 1; }
fi

# Code signing
read -rp "Do you want to sign the installer? (y/n): " SIGN_INSTALLER
SIGN_INSTALLER=${SIGN_INSTALLER,,}
if [[ "$SIGN_INSTALLER" == "y" ]]; then
    read -rp "Enter the path to the signing certificate (.pfx or .pem): " SIGN_CERT
    [[ ! -f "$SIGN_CERT" ]] && { echo "Error: Certificate not found!"; exit 1; }
    read -rsp "Enter the certificate password (if needed): " SIGN_PASS
    echo
fi

# EULA
read -rp "Do you want to display a license agreement (EULA)? (y/n): " SHOW_EULA
SHOW_EULA=${SHOW_EULA,,}
if [[ "$SHOW_EULA" == "y" ]]; then
    read -rp "Enter the path to your EULA text file (.txt or .rtf): " EULA_FILE
    [[ ! -f "$EULA_FILE" ]] && { echo "Error: EULA file not found!"; exit 1; }
fi
if [[ "$PRINT_EULA" == "1" ]]; then
# === Begin writing NSIS script ===
echo "!define APPNAME \"$APP_NAME\"" > "$NSIS_SCRIPT"
echo "!define EXE_NAME \"main.exe\"" >> "$NSIS_SCRIPT"
echo "!define INSTALL_DIR \"$INSTALL_DIR\"" >> "$NSIS_SCRIPT"

echo "Outfile \"$INSTALLER_EXE\"" >> "$NSIS_SCRIPT"
echo "InstallDir \${INSTALL_DIR}" >> "$NSIS_SCRIPT"
echo "RequestExecutionLevel admin" >> "$NSIS_SCRIPT"

# Icon
[[ "$USE_ICON" == "y" ]] && echo "Icon \"$ICON_FILE\"" >> "$NSIS_SCRIPT"

# Optional EULA for interactive mode
if [[ "$SHOW_EULA" == "y" ]]; then
cat >> "$NSIS_SCRIPT" <<EOL
Function .onInit
    IfSilent +2 0
    LicenseData "$EULA_FILE"
FunctionEnd
EOL
fi

# Start section
cat >> "$NSIS_SCRIPT" <<EOL
Section "Install"
    SetOutPath "\${INSTALL_DIR}"
    File main.exe
EOL

# Startup
[[ "$STARTUP" == "y" ]] && echo '    WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Run" "$APPNAME" "$INSTDIR\\main.exe"' >> "$NSIS_SCRIPT"

# Service
if [[ "$INSTALL_SERVICE" == "y" ]]; then
cat >> "$NSIS_SCRIPT" <<EOL
    nsExec::Exec 'sc create "$SERVICE_NAME" binPath= "\$INSTDIR\\main.exe" start= auto'
    nsExec::Exec 'sc start "$SERVICE_NAME"'
EOL
fi

# Downloads
if [[ "$DOWNLOAD_FILES" == "y" && ${#DOWNLOAD_URLS[@]} -gt 0 ]]; then
    echo "    ; Download extra files" >> "$NSIS_SCRIPT"
    for URL in "${DOWNLOAD_URLS[@]}"; do
        FILE_NAME=$(basename "$URL")
        echo "    NSISdl::download \"$URL\" \"\$INSTDIR\\$FILE_NAME\"" >> "$NSIS_SCRIPT"
    done
fi

# Registry keys
[[ "$ADD_REGISTRY" == "y" ]] && echo '    WriteRegStr HKLM "Software\\$APPNAME" "Installed" "1"' >> "$NSIS_SCRIPT"

# End section
echo "SectionEnd" >> "$NSIS_SCRIPT"

# === Compile NSIS ===
if command -v makensis &>/dev/null; then
    makensis "$NSIS_SCRIPT"
    echo "Installer built: $INSTALLER_EXE"
else
    echo "Error: makensis not found."
    exit 1
fi

# === Optional Signing ===
if [[ "$SIGN_INSTALLER" == "y" ]]; then
    if command -v osslsigncode &>/dev/null; then
        osslsigncode sign -pkcs12 "$SIGN_CERT" -pass "$SIGN_PASS" \
        -n "$APP_NAME Installer" -i "https://example.com" \
        -in "$INSTALLER_EXE" -out "Signed-$INSTALLER_EXE"
    elif command -v signtool &>/dev/null; then
        signtool sign /f "$SIGN_CERT" /p "$SIGN_PASS" /t http://timestamp.digicert.com "$INSTALLER_EXE"
    else
        echo "Warning: No code signing tool found."
    fi
fi