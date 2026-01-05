#! /bin/bash

set -e
set -o pipefail

bold=$(tput bold)
red=$(tput setaf 1)
green=$(tput setaf 2)
normal=$(tput sgr0)

# Check if GnuPG is installed
if ! command -v gpg &> /dev/null; then
  echo "Error: gpg command not found${normal}" >&2
  exit 1
fi

# Check if GnuPG version is 2.3 or later
gpg_version=$(gpg --version | head -n 1 | awk '{print $3}')
gpg_major=$(echo "$gpg_version" | cut -d. -f1)
gpg_minor=$(echo "$gpg_version" | cut -d. -f2)

if [ "$gpg_major" -lt 2 ] || ([ "$gpg_major" -eq 2 ] && [ "$gpg_minor" -lt 3 ]); then
  echo "Error: GnuPG 2.3 or later required (found $gpg_version)" >&2
  exit 1
fi

# Create temporary directory
temp=$(mktemp -d)

# Configure GnuPG
# See https://www.gnupg.org/documentation/manuals/gnupg/GPG-Configuration-Options.html
export GNUPGHOME="$temp/.gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
cat << EOF > "$GNUPGHOME/gpg.conf"
keyid-format 0xlong
with-fingerprint
EOF

# Helper function to display main help
function show_main_help() {
  cat << EOF
Usage: yubikey-prov.sh <command> [options]

Commands:
  provision  Provision YubiKey
  restore    Restore PGP subkeys to YubiKey
  extend     Extend PGP subkeys expiry

Run 'yubikey-prov.sh <command> --help' for command-specific options

Options:
  -h, --help  Show this help message
EOF
}

# Helper function to derive handle from first and last name
function derive_handle() {
  local first_name="$1"
  local last_name="$2"
  echo -n "$first_name$last_name" | awk '{gsub (" ", "", $0); print tolower($0)}'
}

# Helper function to get PGP fingerprint
function get_pgp_fingerprint() {
  # See https://www.gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html
  gpg --list-options show-only-fpr-mbox --list-secret-keys --quiet | awk '{print $1}'
}

# Helper function to prompt for and validate PGP secret keys path
function prompt_and_validate_secret_keys() {  
  if [ -z "$secret_keys" ]; then
    printf "${bold}%s${normal}" "Secret keys path: "
    read secret_keys
    if [ -z "$secret_keys" ]; then
      echo "Error: PGP secret keys path cannot be empty" >&2
      exit 1
    fi
  fi

  # Strip single quotes if present
  secret_keys="${secret_keys//\'/}"
  
  if [ ! -f "$secret_keys" ]; then
    echo "Error: PGP secret keys file not found: $secret_keys" >&2
    exit 1
  fi
}

# Helper function to import PGP secret keys
function import_pgp_secret_keys() {
  # Import PGP secret keys
  # See https://www.gnupg.org/documentation/manuals/gnupg/GPG-Input-and-Output.html

  printf "${bold}%s${normal}\n" "Importing PGP secret keys…"

  if ! gpg \
    --batch \
    --quiet \
    --import $secret_keys \
  ; then
    echo "Error: Failed to import PGP secret keys" >&2
    exit 1
  fi

  fingerprint=$(get_pgp_fingerprint)

  # Trust imported PGP secret keys
  # See https://www.gnupg.org/documentation/manuals/gnupg/GPG-Esoteric-Options.html
  # See https://www.gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html

  printf "${bold}%s${normal}\n" "Trusting imported PGP secret keys…"

  if ! echo -e "trust\n5\ny\n" | gpg \
    --batch \
    --command-fd 0 \
    --no-tty \
    --edit-key $fingerprint \
    > /dev/null \
  ; then
    echo "Error: Failed to trust imported PGP secret keys" >&2
    exit 1
  fi
}

# Helper function to parse PGP secret keys and derive handle
function parse_secret_keys_info() {
  # Parse PGP secret keys
  # See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html

  printf "${bold}%s${normal}\n" "Parsing PGP secret keys…"

  user_id=$(gpg --list-packets $secret_keys  | grep 'user ID' | sed 's/.*"\(.*\)".*/\1/')

  if [[ $user_id =~ ^([^\ ]+)\ ([^<]+)\ \<([^>]+)\>$ ]]; then
    first_name="${BASH_REMATCH[1]}"
    last_name="${BASH_REMATCH[2]}"
    email="${BASH_REMATCH[3]}"
  else
    echo "Error: Failed to parse PGP secret keys" >&2
    exit 1
  fi

  # Derive handle from first and last name
  handle=$(derive_handle "$first_name" "$last_name")
}

# Helper function to export PGP public key
function export_pgp_public_key() {
  # Export PGP public key
  # See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html

  printf "${bold}%s${normal}\n" "Exporting PGP public key…"

  if ! gpg \
    --armor \
    --export $fingerprint \
    > "$HOME/Desktop/${handle}.asc" \
  ; then
    echo "Error: Failed to export PGP public key" >&2
    exit 1
  fi
}

# Helper function to ask user to insert YubiKey if not inserted
function wait_for_yubikey () {
  # Check if YubiKey is inserted
  # See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html
  
  if ! gpg --card-status &> /dev/null; then
    printf "${bold}%s${normal}" "Insert YubiKey and press enter"
    read confirmation
    wait_for_yubikey
  fi
}

# Helper function to factory reset YubiKey
function factory_reset_yubikey () {
  local yes=$1

  if [ "$yes" != true ]; then
    printf "${bold}${red}%s${normal}" "This will factory reset YubiKey OpenPGP app. Do you wish to proceed (y or n)? "
    read answer
    if [ "$answer" != "y" ]; then
      exit 0
    fi
  fi

  # Factory reset YubiKey OpenPGP app
  # See https://www.gnupg.org/documentation/manuals/gnupg/GPG-Esoteric-Options.html
  # See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html#Operational-GPG-Commands

  printf "${bold}%s${normal}\n" "Factory resetting YubiKey OpenPGP app…"

  if ! echo -e "admin\nfactory-reset\ny\nyes\n" | gpg \
    --batch \
    --command-fd=0 \
    --logger-fd 1 \
    --no-tty \
    --card-edit \
    > /dev/null \
  ; then
    echo "Error: Factory reset YubiKey OpenPGP app" >&2
    exit 1
  fi

  # Restart gpg-agent
  gpgconf --kill gpg-agent
}

# Helper function to configure YubiKey
function configure_yubikey () {
  local first_name="$1"
  local last_name="$2"
  local email="$3"
  local force_sig="$4"

  # Configure YubiKey OpenPGP app profile
  # See https://www.gnupg.org/documentation/manuals/gnupg/GPG-Esoteric-Options.html
  # See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html#Operational-GPG-Commands
  
  printf "${bold}%s${normal}\n" "Configuring YubiKey OpenPGP app profile…"
  
  if ! echo -e "admin\nname\n$last_name\n$first_name\nlang\nen\nlogin\n$email\nquit" | gpg \
    --batch \
    --command-fd 0 \
    --no-tty \
    --passphrase-fd 3 \
    --pinentry-mode loopback \
    --quiet \
    --card-edit \
    3<<<"12345678" \
  ; then
    echo "Error: Failed to configure YubiKey OpenPGP app profile" >&2
    exit 1
  fi

  # Configure YubiKey OpenPGP app subkeys
  # See https://www.gnupg.org/documentation/manuals/gnupg/GPG-Esoteric-Options.html
  # See https://www.gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html

  printf "${bold}%s${normal}\n" "Configuring YubiKey OpenPGP app subkeys…"

  if ! echo -e "key 1\nkeytocard\n1\nkey 1\nkey 2\nkeytocard\n2\nkey 2\nkey 3\nkeytocard\n3\nkey 3\nsave\n" | gpg \
    --batch \
    --command-fd 0 \
    --no-tty \
    --passphrase-fd 3 \
    --pinentry-mode loopback \
    --quiet \
    --edit-key $fingerprint \
    3<<<"12345678" \
  ; then
    echo "Error: Failed to configure YubiKey OpenPGP app subkeys" >&2
    exit 1
  fi
  
  # Configure YubiKey OpenPGP app policy
  # See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html#Operational-GPG-Commands
  
  printf "${bold}%s${normal}\n" "Configuring YubiKey OpenPGP app policy…"
  
  # Build command with optional forcesig
  local cmd="admin"
  if [ "$force_sig" = true ]; then
    cmd="${cmd}\nforcesig"
  fi
  cmd="${cmd}\nuif 1 on\nuif 2 on\nuif 3 on\nquit"
  
  if ! echo -e "$cmd" | gpg \
    --batch \
    --command-fd 0 \
    --no-tty \
    --passphrase-fd 3 \
    --pinentry-mode loopback \
    --card-edit \
    3<<<"12345678" \
  ; then
    echo "Error: Failed to configure YubiKey OpenPGP app policy" >&2
    exit 1
  fi

  # Configure YubiKey OpenPGP app user passphrase
  # See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html#Operational-GPG-Commands

  printf "${bold}%s${normal}\n" "Configuring YubiKey OpenPGP app user passphrase…"

  printf "${bold}%s${normal}" "Enter user passphrase: "
  read user_passphrase

  tput cuu1
  tput el

  if ! echo -e "admin\npasswd\n1\n123456\n$user_passphrase\n$user_passphrase\nq\nquit\n" | gpg \
    --command-fd 0 \
    --logger-fd 1 \
    --no-tty \
    --pinentry-mode loopback \
    --card-edit  \
    > /dev/null \
  ; then
    echo "Error: Failed to configure YubiKey OpenPGP app user passphrase" >&2
    exit 1
  fi

  # Configure YubiKey OpenPGP app admin passphrase (press enter to use user passphrase)
  # See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html#Operational-GPG-Commands

  printf "${bold}%s${normal}\n" "Configuring YubiKey OpenPGP app admin passphrase (press enter to use user passphrase)…"

  printf "${bold}%s${normal}" "Enter admin passphrase: "
  read admin_passphrase

  admin_passphrase="${admin_passphrase:-$user_passphrase}"

  tput cuu1
  tput el

  if ! echo -e "admin\npasswd\n3\n12345678\n$admin_passphrase\n$admin_passphrase\nq\nquit\n" | gpg \
    --command-fd 0 \
    --logger-fd 1 \
    --no-tty \
    --pinentry-mode loopback \
    --card-edit  \
    > /dev/null \
  ; then
    echo "Error: Failed to configure YubiKey OpenPGP app admin passphrase" >&2
    exit 1
  fi

  # Test YubiKey OpenPGP app
  # See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html

  printf "${bold}%s${normal}\n" "Testing YubiKey OpenPGP app (touch YubiKey)…"

  if ! echo -n "hello" | gpg \
    --armor \
    --encrypt \
    --passphrase-fd 3 \
    --pinentry-mode loopback \
    --recipient $fingerprint \
    --sign \
    3<<<"$user_passphrase" \
  ; then
    echo "Error: Failed to test YubiKey OpenPGP app" >&2
    exit 1
  fi

  # Show YubiKey OpenPGP app configuration
  # See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html

  printf "${bold}%s${normal}\n" "YubiKey OpenPGP app configuration:"

  gpg --card-status
}

function provision_command() {
  local first_name=""
  local last_name=""
  local email=""
  local expiry="1y"
  local force_sig=false
  local yes=false
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        cat << EOF
Usage: yubikey-prov.sh provision [options]

Options:
  --first-name <name>  First name
  --last-name <name>   Last name
  --email <email>      Email
  --expiry <expiry>    Subkey expiry (default: "$expiry")
  --force-sig          Disable GPG agent passphrase caching
  --yes                Disable confirmation prompts
  -h, --help           Show this help message
EOF
        exit 0
        ;;
      --first-name)
        if [[ -z "$2" || "$2" =~ ^- ]]; then
          echo "Error: --first-name requires a value" >&2
          exit 1
        fi
        first_name="$2"
        shift 2
        ;;
      --last-name)
        if [[ -z "$2" || "$2" =~ ^- ]]; then
          echo "Error: --last-name requires a value" >&2
          exit 1
        fi
        last_name="$2"
        shift 2
        ;;
      --email)
        if [[ -z "$2" || "$2" =~ ^- ]]; then
          echo "Error: --email requires a value" >&2
          exit 1
        fi
        email="$2"
        shift 2
        ;;
      --expiry)
        if [[ -z "$2" || "$2" =~ ^- ]]; then
          echo "Error: --expiry requires a value" >&2
          exit 1
        fi
        expiry="$2"
        shift 2
        ;;
      --force-sig)
        force_sig=true
        shift
        ;;
      --yes)
        yes=true
        shift
        ;;
      -*)
        echo "Error: Unknown option: $1" >&2
        exit 1
        ;;
      *)
        echo "Error: Unexpected argument: $1" >&2
        exit 1
        ;;
    esac
  done
  
  # Ask user for missing options
  if [ -z "$first_name" ]; then
    printf "${bold}%s${normal}" "First name: "
    read first_name
    if [ -z "$first_name" ]; then
      echo "Error: First name cannot be empty" >&2
      exit 1
    fi
  fi
  if [ -z "$last_name" ]; then
    printf "${bold}%s${normal}" "Last name: "
    read last_name
    if [ -z "$last_name" ]; then
      echo "Error: Last name cannot be empty" >&2
      exit 1
    fi
  fi
  if [ -z "$email" ]; then
    printf "${bold}%s${normal}" "Email: "
    read email
    if [ -z "$email" ]; then
      echo "Error: Email cannot be empty" >&2
      exit 1
    fi
  fi

  # Derive handle from first and last name
  handle=$(derive_handle "$first_name" "$last_name")

  # Create PGP key
  # See https://www.gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html

  printf "${bold}%s${normal}\n" "Creating PGP key…"

  if ! gpg \
    --batch \
    --passphrase "" \
    --quiet \
    --quick-generate-key "$first_name $last_name <$email>" ed25519 cert 0 \
  ; then
    echo "Error: Failed to create PGP key" >&2
    exit 1
  fi

  fingerprint=$(get_pgp_fingerprint)

  # Create PGP subkeys
  # See https://www.gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html

  printf "${bold}%s${normal}\n" "Creating PGP subkeys…"

  if ! gpg \
    --batch \
    --passphrase "" \
    --quick-add-key $fingerprint ed25519 sign ${expiry} \
  ; then
    echo "Error: Failed to create signing subkey" >&2
    exit 1
  fi

  if ! gpg \
    --batch \
    --passphrase "" \
    --quick-add-key $fingerprint cv25519 encr ${expiry} \
  ; then
    echo "Error: Failed to create encryption subkey" >&2
    exit 1
  fi

  if ! gpg \
    --batch \
    --passphrase "" \
    --quick-add-key $fingerprint ed25519 auth ${expiry} \
  ; then
    echo "Error: Failed to create authentication subkey" >&2
    exit 1
  fi

  # Export PGP secret keys
  # See https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html

  printf "${bold}%s${normal}\n" "Exporting PGP secret keys…"

  if ! gpg \
    --armor \
    --export-secret-keys $fingerprint \
    > "$HOME/Desktop/${handle}-secret-keys.asc" \
  ; then
    echo "Error: Failed to export PGP secret keys" >&2
    exit 1
  fi

  export_pgp_public_key

  wait_for_yubikey

  factory_reset_yubikey $yes

  configure_yubikey "$first_name" "$last_name" "$email" "$force_sig"

  printf "${bold}${green}%s${normal}\n" "YubiKey provisioned"

  exit 0
}

function restore_command() {
  local secret_keys=""
  local force_sig=false
  local yes=false
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        cat << EOF
Usage: yubikey-prov.sh restore [options]

Options:
  --secret-keys <path>  Path to PGP secret keys
  --force-sig           Disable GPG agent passphrase caching
  --yes                 Disable confirmation prompts
  -h, --help            Show this help message
EOF
        exit 0
        ;;
      --secret-keys)
        if [[ -z "$2" || "$2" =~ ^- ]]; then
          echo "Error: --secret-keys requires a value" >&2
          exit 1
        fi
        secret_keys="$2"
        shift 2
        ;;
      --force-sig)
        force_sig=true
        shift
        ;;
      --yes)
        yes=true
        shift
        ;;
      -*)
        echo "Error: Unknown option: $1" >&2
        exit 1
        ;;
      *)
        echo "Error: Unexpected argument: $1" >&2
        exit 1
        ;;
    esac
  done
  
  prompt_and_validate_secret_keys

  import_pgp_secret_keys

  parse_secret_keys_info

  wait_for_yubikey

  factory_reset_yubikey $yes

  configure_yubikey "$first_name" "$last_name" "$email" "$force_sig"

  printf "${bold}${green}%s${normal}\n" "YubiKey restored"

  exit 0
}

function extend_command() {
  local secret_keys=""
  local expiry="1y"
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        cat << EOF
Usage: yubikey-prov.sh extend [options]

Options:
  --secret-keys <path>  Path to PGP secret keys
  --expiry <expiry>     Subkey expiry (default: "$expiry")
  -h, --help            Show this help message
EOF
        exit 0
        ;;
      --secret-keys)
        if [[ -z "$2" || "$2" =~ ^- ]]; then
          echo "Error: --secret-keys requires a value" >&2
          exit 1
        fi
        secret_keys="$2"
        shift 2
        ;;
      --expiry)
        if [[ -z "$2" || "$2" =~ ^- ]]; then
          echo "Error: --expiry requires a value" >&2
          exit 1
        fi
        expiry="$2"
        shift 2
        ;;
      -*)
        echo "Error: Unknown option: $1" >&2
        exit 1
        ;;
      *)
        echo "Error: Unexpected argument: $1" >&2
        exit 1
        ;;
    esac
  done
  
  prompt_and_validate_secret_keys

  import_pgp_secret_keys

  parse_secret_keys_info

  # Extend expiry of PGP subkeys
  # See https://www.gnupg.org/documentation/manuals/gnupg/GPG-Esoteric-Options.html
  # See https://www.gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html

  printf "${bold}%s${normal}\n" "Extending expiry of PGP subkeys…"

  echo -e "key 1\nkey 2\nkey 3\nexpire\ny\n${expiry}\ny\nsave" | gpg \
    --batch \
    --command-fd 0 \
    --no-tty \
    --quiet \
    --edit-key $fingerprint

  export_pgp_public_key

  printf "${bold}${green}%s${normal}\n" "PGP subkeys expiry extended"

  exit 0
}

# Check for command
if [ $# -eq 0 ]; then
  show_main_help
  exit 0
fi

command="$1"
shift

# Handle main help flags before processing command
if [ "$command" = "-h" ] || [ "$command" = "--help" ]; then
  show_main_help
  exit 0
fi

# Process command
case "$command" in
  provision)
    provision_command "$@"
    ;;
  restore)
    restore_command "$@"
    ;;
  extend)
    extend_command "$@"
    ;;
  *)
    echo "Error: Unknown command: $command" >&2
    exit 1
    ;;
esac