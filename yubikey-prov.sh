#! /bin/bash

set -e
set -o pipefail

basedir=$(dirname "$0")

function dismount()
{
  if [ -d "$veracrypt_encrypted_volume" ]; then
    "${veracrypt[@]}" --text --dismount "$veracrypt_encrypted_volume"
  fi
}

# Dismount VeraCrypt encrypted volume if script errors out or is interrupted
trap dismount ERR INT

# Set formatting variables
bold=$(tput bold)
red=$(tput setaf 1)
normal=$(tput sgr0)

# Set default command line argument variables
expiry=1
nfc="FIDO2"
usb="FIDO2 OPENPGP"

# Process command line arguments
positional=()
while [ $# -gt 0 ]; do
  argument="$1"
  case $argument in
    -h|--help)
    printf "%s\n" \
    "Usage: yubikey-prov.sh [options]" \
    "" \
    "Options:" \
    "  --first-name <name>  first name" \
    "  --last-name <name>   last name" \
    "  --email <email>      email" \
    "  --expiry <expiry>    subkey expiry (defaults to 1)" \
    "  --signing-key <path> sign public key using signing key (optional)" \
    "  --nfc <nfc>          enable NFC interfaces (defaults to \"FIDO2\")" \
    "  --usb <usb>          enable USB interfaces (defaults to \"FIDO2 OPENPGP\")" \
    "  --lock-code <code>   set lock-code (optional)" \
    "  --yes                disable confirmation prompts" \
    "  -h, --help           display help for command"
    exit 0
    ;;
    --first-name)
    first_name=$2
    shift
    shift
    ;;
    --last-name)
    last_name=$2
    shift
    shift
    ;;
    --email)
    email=$2
    shift
    shift
    ;;
    --expiry)
    expiry=$2
    shift
    shift
    ;;
    --signing-key)
    signing_key=$2
    shift
    shift
    ;;
    --nfc)
    nfc=$2
    shift
    shift
    ;;
    --usb)
    usb=$2
    shift
    shift
    ;;
    --lock-code)
    lock_code=$2
    shift
    shift
    ;;
    --yes)
    yes=true
    shift
    ;;
    *)
    positional+=("$1")
    shift
    ;;
  esac
done

set -- "${positional[@]}"

# Check if required command line arguments are set
if [ -z "$first_name" ] || [ -z "$last_name" ] || [ -z "$email" ]; then
  printf "$bold$red%s$normal\n" "Invalid first name, last name or email argument, see --help"
  exit 1
fi

# Set user_id variable
user_id=$(echo -n "$first_name$last_name" | awk '{gsub (" ", "", $0); print tolower($0)}')

# Confirm macOS usage
if [ "$(uname)" = "Darwin" ] && [ "$yes" != true ]; then
  printf \
    "$bold$red%s$normal\n" \
    "Running yubikey-prov.sh on macOS is not recommended unless operating system has been hardened and is offline and read-only." \
    "Do you wish to proceed (y or n)?"
  read -r answer
  if [ "$answer" != "y" ]; then
    printf "%s\n" "Cancelled"
    exit 0
  fi
fi

# Set ykman variable (if applicable)
if [ -f /home/amnesia/Persistent/yubikey-manager-qt.AppImage ]; then
  ykman=("/home/amnesia/Persistent/yubikey-manager-qt.AppImage" ykman)
elif [ -f /Applications/YubiKey\ Manager.app/Contents/MacOS/ykman ]; then
  ykman=("/Applications/YubiKey Manager.app/Contents/MacOS/ykman")
else
  printf "$bold$red%s$normal\n" "Could not find YubiKey Manager binary"
  exit 1
fi

# Set veracrypt variable (if applicable)
if [ -f /home/amnesia/Persistent/veracrypt ]; then
  veracrypt=(sudo "/home/amnesia/Persistent/veracrypt")
elif [ -f /Applications/VeraCrypt.app/Contents/MacOS/VeraCrypt ]; then
  veracrypt=("/Applications/VeraCrypt.app/Contents/MacOS/VeraCrypt")
else
  printf "$bold$red%s$normal\n" "Could not find VeraCrypt binary"
  exit 1
fi

# Set keepassxc_cli variable (if applicable)
if [ -f /usr/bin/keepassxc-cli ]; then
  keepassxc_cli="keepassxc-cli"
elif [ -f /Applications/KeePassXC.app/Contents/MacOS/keepassxc-cli ]; then
  keepassxc_cli="/Applications/KeePassXC.app/Contents/MacOS/keepassxc-cli"
else
  printf "$bold$red%s$normal\n" "Could not find keepassxc-cli binary"
  exit 1
fi

# Wait for SD card to be inserted
wait_for_sd_card () {
  # Set veracrypt_file and veracrypt_encrypted_volume variables
  if [ -f "/media/amnesia/Data/tails" ]; then
    data_volume="/media/amnesia/Data"
    veracrypt_file="$data_volume/tails"
    veracrypt_encrypted_volume="/media/veracrypt1"
  elif [ -f "/Volumes/Data/tails" ]; then
    data_volume="/Volumes/Data"
    veracrypt_file="$data_volume/tails"
    veracrypt_encrypted_volume="/Volumes/Tails"
  else
    printf "$bold%s$normal" "Insert SD card and press enter"
    read -r confirmation
    wait_for_sd_card
  fi
}
wait_for_sd_card

# Wait for YubiKey to be inserted
wait_for_yubikey () {
  keys=$("${ykman[@]}" list)
  if [ -z "$keys" ]; then
    printf "$bold%s$normal" "Insert YubiKey and press enter"
    read -r confirmation
    wait_for_yubikey
  fi
}
wait_for_yubikey

# Disable YubiKey configuration lock (if applicable)
# See https://docs.yubico.com/software/yubikey/tools/ykman/Base_Commands.html
if [ -n "$lock_code" ]; then
  echo $lock_code | "${ykman[@]}" config set-lock-code --clear
fi

# Confirm YubiKey OpenPGP applet reset
reset_openpgp_applet () {
  "${ykman[@]}" openpgp reset --force
}
if [ "$yes" = true ]; then
  reset_openpgp_applet
else
  printf \
    "$bold$red%s$normal\n" \
    "Resetting YubiKey OpenPGP applet will PERMANENTLY destroy all keys stored on device." \
    "Do you wish to proceed (y or n)?"
  read -r answer
  if [ "$answer" = "y" ]; then
    reset_openpgp_applet
  else
    printf "%s\n" "Cancelled"
    exit 0
  fi
fi

# Mount VeraCrypt encrypted volume
"${veracrypt[@]}" --text --mount --pim "0" --keyfiles "" --protect-hidden "no" "$veracrypt_file" "$veracrypt_encrypted_volume"

# Reset terminal
tput reset

# Create temp directory
tmp=$(mktemp -d)

# Configure GnuPG
# See https://www.gnupg.org/documentation/manuals/gnupg/GPG-Configuration-Options.html
export GNUPGHOME="$tmp/.gnupg"
# See https://www.gnupg.org/documentation/manuals/gnupg/Agent-Options.html
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
cat << EOF > "$GNUPGHOME/gpg.conf"
keyid-format 0xlong
with-fingerprint
EOF
echo "pinentry-program $basedir/insecure-pinentry.sh" > "$GNUPGHOME/gpg-agent.conf"

# Create PGP master key
# See https://www.gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html
gpg \
  --batch \
  --passphrase "" \
  --quick-generate-key "$first_name $last_name <$email>" ed25519 cert 0

# Set PGP master key fingerprint variable
# See https://www.gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html
fingerprint=$(gpg --list-options show-only-fpr-mbox --list-secret-keys | awk '{print $1}')

# Create PGP subkeys
# See https://www.gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html
gpg \
  --batch \
  --passphrase "" \
  --quick-add-key $fingerprint ed25519 sign ${expiry}y
gpg \
  --batch \
  --passphrase "" \
  --quick-add-key $fingerprint cv25519 encr ${expiry}y
gpg \
  --batch \
  --passphrase "" \
  --quick-add-key $fingerprint ed25519 auth ${expiry}y

# Sign public key using signing key (if applicable)
if [ -n "$signing_key" ]; then
  # Set signing_key_id variable
  # See https://www.gnupg.org/documentation/manuals/gnupg/GPG-Input-and-Output.html
  signing_key_id=$(gpg --import-options show-only --import "$signing_key" | grep sec | awk '{print $2}' | awk -F "/" '{print $2}')
  # Import signing key
  # See https://www.gnupg.org/documentation/manuals/gnupg-devel/Operational-GPG-Commands.html
  gpg --import "$signing_key"
  # Sign public key using signing key
  # See https://www.gnupg.org/documentation/manuals/gnupg/GPG-Configuration-Options.html
  # See https://www.gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html
  echo -e "3\ny" | gpg \
    --command-fd 0 \
    --ask-cert-level \
    --default-key $signing_key_id \
    --sign-key $fingerprint
fi

# List PGP keys
# See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html#Operational-GPG-Commands
printf "$bold%s$normal\n" "PGP keys:"
gpg --list-keys
printf "\n"

# Make sure pgp directory exists
public_pgp_dir="$data_volume/PGP"
mkdir -p "$public_pgp_dir"
encrypted_pgp_dir="$veracrypt_encrypted_volume/PGP"
mkdir -p "$encrypted_pgp_dir"

# Backup PGP master key, subkeys and public key to VeraCrypt encrypted volume
# See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html#Operational-GPG-Commands
gpg --armor --export-secret-keys $fingerprint > "$encrypted_pgp_dir/${user_id}_master.asc"
gpg --armor --export-secret-subkeys $fingerprint > "$encrypted_pgp_dir/${user_id}_sub.asc"
gpg --armor --export $fingerprint > "$encrypted_pgp_dir/${user_id}.asc"

# Copy PGP public key to “Data” volume
cp "$encrypted_pgp_dir/${user_id}.asc" "$public_pgp_dir"

# Copy subkeys to YubiKey
# See https://www.gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html
echo -e "key 1\nkeytocard\n1\nkey 1\nkey 2\nkeytocard\n2\nkey 2\nkey 3\nkeytocard\n3\nsave" | gpg \
  --command-fd 0 \
  --passphrase-fd 3 \
  --pinentry-mode loopback \
  --edit-key $fingerprint \
  3<<<"12345678"

# Configure YubiKey OpenPGP applet settings
# See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html#Operational-GPG-Commands
echo -e "admin\nname\n$last_name\n$first_name\nlang\nen\nlogin\n$email\nquit" | gpg \
  --command-fd 0 \
  --passphrase-fd 3 \
  --pinentry-mode loopback \
  --card-edit \
  3<<<"12345678"

# Set interfaces variable
interfaces="FIDO2 HSMAUTH OATH OPENPGP OTP PIV U2F"

# Function used to remove items $2 from list $1
filter () {
  array1=($1)
  array2=($2)
  for item in ${array2[@]}; do
    array1=("${array1[@]/$item}")
  done
  echo ${array1[@]}
}

# Configure YubiKey NFC interfaces
# See https://docs.yubico.com/software/yubikey/tools/ykman/Base_Commands.html#ykman-config-nfc-options
enabled_nfc_interfaces=($nfc)
disabled_nfc_interfaces=($(filter "$interfaces" "$nfc"))
nfc_arguments=()
for interface in ${enabled_nfc_interfaces[@]}; do
  nfc_arguments+=("--enable $interface")
done
for interface in ${disabled_nfc_interfaces[@]}; do
  nfc_arguments+=("--disable $interface")
done
"${ykman[@]}" config nfc ${nfc_arguments[@]} --force

# Wait for YubiKey to reboot
sleep 3

# Configure YubiKey USB interfaces
# See https://docs.yubico.com/software/yubikey/tools/ykman/Base_Commands.html#ykman-config-usb-options
enabled_usb_interfaces=($usb)
disabled_usb_interfaces=($(filter "$interfaces" "$usb"))
usb_arguments=()
for interface in ${enabled_usb_interfaces[@]}; do
  usb_arguments+=("--enable $interface")
done
for interface in ${disabled_usb_interfaces[@]}; do
  usb_arguments+=("--disable $interface")
done
"${ykman[@]}" config usb ${usb_arguments[@]} --force

# Wait for YubiKey to reboot
sleep 3

# Enable YubiKey configuration lock (if applicable)
# See https://docs.yubico.com/software/yubikey/tools/ykman/Base_Commands.html
if [ -n "$lock_code" ]; then
  echo $lock_code | "${ykman[@]}" config set-lock-code --force
fi

# Enable YubiKey user interaction
# See https://docs.yubico.com/software/yubikey/tools/ykman/OpenPGP_Commands.html
echo "12345678" | "${ykman[@]}" openpgp keys set-touch sig on --force
echo "12345678" | "${ykman[@]}" openpgp keys set-touch enc on --force
echo "12345678" | "${ykman[@]}" openpgp keys set-touch aut on --force
echo "12345678" | "${ykman[@]}" openpgp keys set-touch att on --force

# Set user PIN
# See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html#Operational-GPG-Commands
echo -e "1\nq" | PINENTRY_USER_DATA="123456,$pin" gpg \
  --command-fd 0 \
  --change-pin

# Set admin PIN
# See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html#Operational-GPG-Commands
echo -e "3\nq" | PINENTRY_USER_DATA="12345678,$admin_pin" gpg \
  --command-fd 0 \
  --change-pin

# Show card status
# See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html#Operational-GPG-Commands
printf "$bold%s$normal\n" "Card status:"
gpg --card-status
printf "\n"

# Show YubiKey info
# See https://docs.yubico.com/software/yubikey/tools/ykman/Base_Commands.html#ykman-options-command-args
printf "$bold%s$normal\n" "YubiKey info:"
"${ykman[@]}" info
printf "\n"

# Reboot YubiKey
printf "$bold%s$normal" "Remove and insert YubiKey and press enter"
read -r confirmation

# Generate and back up user and admin PIN
pin=$("$keepassxc_cli" diceware --words 5 --word-list "$basedir/eff_short_wordlist_1.txt" 2> /dev/null)
admin_pin=$("$keepassxc_cli" diceware --words 5 --word-list "$basedir/eff_short_wordlist_1.txt" 2> /dev/null)
cat << EOF > "$encrypted_pgp_dir/${user_id}.txt"
Card status:
$(gpg --card-status)

PGP pub key signatures:
$(gpg --list-signatures $fingerprint)

YubiKey info:
$("${ykman[@]}" info)

User PIN: $pin
Admin PIN: $admin_pin
EOF

# Confirm backup integrity
if [ "$(uname)" = "Darwin" ]; then
  open "$encrypted_pgp_dir"
elif [[ "$(uname -a)" =~ amnesia ]]; then
  xdg-open "$encrypted_pgp_dir"
else
  printf "$bold$red%s$normal\n" "Invalid operating system"
  exit 1
fi
printf "$bold%s$normal" "Confirm backup integrity and press enter"
read -r confirmation

# Dismount VeraCrypt encrypted volume
dismount

printf "%s\n" "Done"
