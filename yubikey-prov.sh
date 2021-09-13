#! /bin/bash

set -e
set -o pipefail

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

# Set basedir variable
# See https://stackoverflow.com/a/4774063/4579271
basedir=$(cd "$(dirname "$0")" > /dev/null 2>&1; pwd)

# Set interfaces variable
# See https://docs.yubico.com/software/yubikey/tools/ykman/Base_Commands.html#ykman-config-nfc-options
interfaces="FIDO2 HSMAUTH OATH OPENPGP OTP PIV U2F"

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
    "  --signing-key <path> signing key used to sign pub keys (optional)" \
    "  --nfc <nfc>          enabled NFC applets (defaults to \"FIDO2\")" \
    "  --usb <usb>          enabled USB applets (defaults to \"FIDO2 OPENPGP\")" \
    "  --lock-code <code>   configuration lock-code (optional)" \
    "  --reset              reset applets to factory defaults" \
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
    --reset)
    reset=true
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
    dismount
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

# Set pin and admin_pin variables
pin=$("$keepassxc_cli" diceware --words 5 --word-list "$basedir/eff_short_wordlist_1.txt" 2> /dev/null)
admin_pin=$("$keepassxc_cli" diceware --words 5 --word-list "$basedir/eff_short_wordlist_1.txt" 2> /dev/null)

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

# Reset YubiKey applets to factory defaults (if applicable)
if [ "$reset" = true ]; then
  # Enable all YubiKey applets over USB (required to reset applets to factory defaults)
  usb_arguments=()
  for interface in ${interfaces[@]}; do
    usb_arguments+=("--enable $interface")
  done
  "${ykman[@]}" config usb ${usb_arguments[@]} --force

  # Wait for YubiKey to reboot
  sleep 3

  # Confirm YubiKey FIDO2 and FIDO U2F applet reset
  reset_fido_applet () {
    # Reboot YubiKey
    printf "$bold%s$normal" "Remove and insert YubiKey and press enter"
    read -r confirmation
    # Reset FIDO2 and FIDO U2F applets
    # See https://docs.yubico.com/software/yubikey/tools/ykman/FIDO_Commands.html#ykman-fido-reset-options
    "${ykman[@]}" fido reset --force
  }
  if [ "$yes" = true ]; then
    reset_fido_applet
  else
    printf \
      "$bold$red%s$normal\n" \
      "Resetting YubiKey FIDO2 and FIDO U2F applets will PERMANENTLY destroy all FIDO2 and FIDO U2F accounts stored on device." \
      "Do you wish to proceed (y or n)?"
    read -r answer
    if [ "$answer" = "y" ]; then
      reset_fido_applet
    else
      printf "%s\n" "Cancelled"
      dismount
      exit 0
    fi
  fi

  # Confirm YubiKey OATH applet reset
  reset_oath_applet () {
    # Reset OATH applet
    # See https://docs.yubico.com/software/yubikey/tools/ykman/OATH_Commands.html#ykman-oath-reset-options
    "${ykman[@]}" oath reset --force
  }
  if [ "$yes" = true ]; then
    reset_oath_applet
  else
    printf \
      "$bold$red%s$normal\n" \
      "Resetting YubiKey OATH applet will PERMANENTLY destroy all OATH (also known as TOTP) accounts stored on device." \
      "Do you wish to proceed (y or n)?"
    read -r answer
    if [ "$answer" = "y" ]; then
      reset_oath_applet
    else
      printf "%s\n" "Cancelled"
      dismount
      exit 0
    fi
  fi

  # Confirm YubiKey OpenPGP applet reset
  reset_openpgp_applet () {
    # Reset OATH applet
    # See https://docs.yubico.com/software/yubikey/tools/ykman/OpenPGP_Commands.html#ykman-openpgp-reset-options
    "${ykman[@]}" openpgp reset --force
  }
  if [ "$yes" = true ]; then
    reset_openpgp_applet
  else
    printf \
      "$bold$red%s$normal\n" \
      "Resetting YubiKey OpenPGP applet will PERMANENTLY destroy all PGP keys and settings stored on device." \
      "Do you wish to proceed (y or n)?"
    read -r answer
    if [ "$answer" = "y" ]; then
      reset_openpgp_applet
    else
      printf "%s\n" "Cancelled"
      dismount
      exit 0
    fi
  fi

  # Confirm YubiKey OTP applet reset
  reset_otp_applet () {
    # Reset OTP applet
    # See https://docs.yubico.com/software/yubikey/tools/ykman/OTP_Commands.html#ykman-otp-delete-options-1-2
    # Check if OTP slot 1 needs to be deleted
    if [ "$("${ykman[@]}" otp info | grep "Slot 1")" = "Slot 1: programmed" ]; then
      "${ykman[@]}" otp delete 1 --force
    fi
    # Check if OTP slot 2 needs to be deleted
    if [ "$("${ykman[@]}" otp info | grep "Slot 2")" = "Slot 2: programmed" ]; then
      "${ykman[@]}" otp delete 2 --force
    fi
  }
  if [ "$yes" = true ]; then
    reset_otp_applet
  else
    printf \
      "$bold$red%s$normal\n" \
      "Resetting YubiKey OTP applet will PERMANENTLY destroy all OTP credentials stored on device." \
      "Do you wish to proceed (y or n)?"
    read -r answer
    if [ "$answer" = "y" ]; then
      reset_otp_applet
    else
      printf "%s\n" "Cancelled"
      dismount
      exit 0
    fi
  fi

  # Confirm YubiKey PIV applet reset
  reset_piv_applet () {
    # Reset OTP applet
    # See https://docs.yubico.com/software/yubikey/tools/ykman/PIV_Commands.html#ykman-piv-reset-options
    "${ykman[@]}" piv reset --force
  }
  if [ "$yes" = true ]; then
    reset_piv_applet
  else
    printf \
      "$bold$red%s$normal\n" \
      "Resetting YubiKey PIV applet will PERMANENTLY destroy all smart card data stored on device." \
      "Do you wish to proceed (y or n)?"
    read -r answer
    if [ "$answer" = "y" ]; then
      reset_piv_applet
    else
      printf "%s\n" "Cancelled"
      dismount
      exit 0
    fi
  fi
fi

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

# Set enabled_nfc_applets and disabled_nfc_applets variables
enabled_nfc_applets=($nfc)
disabled_nfc_applets=($(filter "$interfaces" "$nfc"))

# Set enabled_usb_applets and disabled_usb_applets variables
enabled_usb_applets=($usb)
disabled_usb_applets=($(filter "$interfaces" "$usb"))

# Mount VeraCrypt encrypted volume
"${veracrypt[@]}" --text --mount --pim "0" --keyfiles "" --protect-hidden "no" "$veracrypt_file" "$veracrypt_encrypted_volume"

# Configure YubiKey NFC applets
# See https://docs.yubico.com/software/yubikey/tools/ykman/Base_Commands.html#ykman-config-nfc-options
nfc_arguments=()
for interface in ${enabled_nfc_applets[@]}; do
  nfc_arguments+=("--enable $interface")
done
for interface in ${disabled_nfc_applets[@]}; do
  nfc_arguments+=("--disable $interface")
done
"${ykman[@]}" config nfc ${nfc_arguments[@]} --force

# Wait for YubiKey to reboot
sleep 3

# Configure YubiKey USB applets
# See https://docs.yubico.com/software/yubikey/tools/ykman/Base_Commands.html#ykman-config-usb-options
usb_arguments=()
for interface in ${enabled_usb_applets[@]}; do
  usb_arguments+=("--enable $interface")
done
for interface in ${disabled_usb_applets[@]}; do
  usb_arguments+=("--disable $interface")
done
"${ykman[@]}" config usb ${usb_arguments[@]} --force

# Wait for YubiKey to reboot
sleep 3

# Check if OATH applet is enabled
if [[ "$("${ykman[@]}" info | grep OATH)" =~ "Enabled" ]]; then
  oath_enabled=true
fi

# Check if OpenPGP applet is enabled
if [[ "$("${ykman[@]}" info | grep OpenPGP)" =~ "Enabled" ]]; then
  openpgp_enabled=true
fi

# Configure OATH applet (if enabled)
if [ "$oath_enabled" = true ]; then
  # Set password
  echo "$pin" | "${ykman[@]}" oath access change
fi

# Configure OpenPGP applet (if enabled)
if [ "$openpgp_enabled" = true ]; then
  # Create temp directory
  tmp=$(mktemp -d)

  # Configure GnuPG
  # See https://www.gnupg.org/documentation/manuals/gnupg/GPG-Configuration-Options.html
  export GNUPGHOME="$tmp/.gnupg"
  mkdir -p "$GNUPGHOME"
  chmod 700 "$GNUPGHOME"
  cat << EOF > "$GNUPGHOME/gpg.conf"
keyid-format 0xlong
with-fingerprint
EOF

  # See https://www.gnupg.org/documentation/manuals/gnupg/Agent-Options.html
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

  # Make sure PGP directories exists
  public_pgp_dir="$data_volume/PGP"
  mkdir -p "$public_pgp_dir"
  encrypted_pgp_dir="$veracrypt_encrypted_volume/$user_id/PGP"
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

  # Configure YubiKey OpenPGP applet identity
  # See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html#Operational-GPG-Commands
  echo -e "admin\nname\n$last_name\n$first_name\nlang\nen\nlogin\n$email\nquit" | gpg \
    --command-fd 0 \
    --passphrase-fd 3 \
    --pinentry-mode loopback \
    --card-edit \
    3<<<"12345678"

  # Enable YubiKey OpenPGP applet user interaction feature
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
fi

# Enable YubiKey configuration lock (if applicable)
# See https://docs.yubico.com/software/yubikey/tools/ykman/Base_Commands.html
if [ -n "$lock_code" ]; then
  printf \
    "$bold$red%s$normal\n" \
    "Make sure lock code has been carefully backed up as one cannot factory reset code." \
    "Have you carefully backed up lock code (y or n)?"
  read -r answer
  if [ "$answer" = "y" ]; then
    echo $lock_code | "${ykman[@]}" config set-lock-code --force
  else
    printf "%s\n" "Cancelled"
    dismount
    exit 0
  fi
fi

# Reboot YubiKey
printf "$bold%s$normal" "Remove and insert YubiKey and press enter"
read -r confirmation

# Make sure user directories exists
encrypted_user_dir="$veracrypt_encrypted_volume/$user_id"
mkdir -p "$encrypted_user_dir"

# Create user log file
# See https://docs.yubico.com/software/yubikey/tools/ykman/Base_Commands.html#ykman-info-options
cat << EOF > "$encrypted_user_dir/${user_id}.txt"
YubiKey info:
$("${ykman[@]}" info)
EOF

if [ -n "$lock_code" ]; then
  cat << EOF >> "$encrypted_user_dir/${user_id}.txt"

Lock code: $lock_code
EOF
fi

if [ "$oath_enabled" = true ]; then
  cat << EOF >> "$encrypted_user_dir/${user_id}.txt"

OATH password: $pin
EOF
fi

# See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html#Operational-GPG-Commands
if [ "$openpgp_enabled" = true ]; then
  cat << EOF >> "$encrypted_user_dir/${user_id}.txt"

PGP card status:
$(gpg --card-status)

PGP signatures:
$(gpg --list-sigs $fingerprint)

PGP user PIN: $pin
PGP admin PIN: $admin_pin
EOF
fi

# Confirm backup integrity
if [ "$(uname)" = "Darwin" ]; then
  open "$encrypted_user_dir"
elif [[ "$(uname -a)" =~ amnesia ]]; then
  xdg-open "$encrypted_user_dir"
else
  printf "$bold$red%s$normal\n" "Invalid operating system"
  exit 1
fi
printf "$bold%s$normal" "Confirm backup integrity, copy user PIN to clipboard and press enter"
read -r confirmation

# Test YubiKey OATH applet (if applicable)
# See https://docs.yubico.com/software/yubikey/tools/ykman/OATH_Commands.html#ykman-oath-accounts-list-options
if [ "$oath_enabled" = true ]; then
  printf "$bold%s$normal\n" "Testing OATH applet…"
  "${ykman[@]}" oath accounts list
fi

# Test YubiKey OpenPGP applet (if applicable)
# See https://www.gnupg.org/documentation/manpage.html
if [ "$openpgp_enabled" = true ]; then
  printf "$bold%s$normal\n" "Testing OpenPGP applet…"
  echo "foo" | gpg --pinentry-mode loopback --encrypt --sign --armor --recipient $fingerprint
fi

# Dismount VeraCrypt encrypted volume
dismount

printf "%s\n" "Done"
