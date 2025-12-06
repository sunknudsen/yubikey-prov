# yubikey-prov

## Provision, restore and extend PGP subkeys to YubiKey

This utility is used to manage PGP secret keys and YubiKeys on **air-gapped** and **non-persistent** operating systems.

The provisioned `*-secret-keys.asc` file is **not encrypted** therefore it is **mission critical** to store file using encrypted backups for later recovery should YubiKey be damaged or lost.

If you wish to support this project, please star [repo](https://github.com/sunknudsen/yubikey-prov) and consider a [donation](https://sunknudsen.com/donate).

## Requirements

GnuPG 2.3 or later

## Usage

```console
$ ./yubikey-prov.sh --help
Usage: yubikey-prov.sh <command> [options]

Commands:
  provision  Provision YubiKey
  restore    Restore PGP subkeys to YubiKey
  extend     Extend PGP subkeys expiry

Run 'yubikey-prov.sh <command> --help' for command-specific options

Options:
  -h, --help  Show this help message
```

### Provision YubiKey

```console
$ ./yubikey-prov.sh provision --help
Usage: yubikey-prov.sh provision [options]

Options:
  --first-name <name>  First name
  --last-name <name>   Last name
  --email <email>      Email
  --expiry <expiry>    Subkey expiry (default: "1y")
  --force-sig          Disable GPG agent passphrase caching
  --yes                Disable confirmation prompts
  -h, --help           Show this help message

$ ./yubikey-prov.sh provision --first-name Sun --last-name Knudsen --email h****@sunknudsen.com
Creating PGP key…
Creating PGP subkeys…
Exporting PGP secret keys…
Exporting PGP public key…
Insert YubiKey and press enter
This will factory reset YubiKey OpenPGP app. Do you wish to proceed (y or n)? y
Factory resetting YubiKey OpenPGP app…
Configuring YubiKey OpenPGP app profile…
Configuring YubiKey OpenPGP app subkeys…
Configuring YubiKey OpenPGP app policy…
Configuring YubiKey OpenPGP app user passphrase…
Configuring YubiKey OpenPGP app admin passphrase (press enter to use user passphrase)…
Testing YubiKey OpenPGP app (touch YubiKey)…
-----BEGIN PGP MESSAGE-----

hF4DAfkMPHF+pi0SAQdAMYXlX9iW70DrzpueYTqKUXCceYlm7tFO2ob+7BxOI3Iw
l0WgcR8vNNjKGpvA+IPCtDONhmsab93824NkaFa8KKDlTe9sCVCUi7ejo8TRSsR7
1MAHAQkCECbfgPaSMJqD/4NJihpTGNN8faxXDPShTlG6GKB+fLHqBh9qABI6Wibr
vRXq35+mfMmxCYpY3RTBo3mcgRQw65nZE1NKIHWVo7GimQXkF8Qzd7LWhGP0j3qR
dHHLJfmxlkc3XZZaHVKrmUhYe2sfb8Tb8eKZpv+Oi4rArgtna++HKfTFwHNPQF/6
nRuRUyLH/a11BIWEmyf6h4lJUwF85DCnNxtzVOmD4nlx/2nF0ETyHYGpsEM/tYje
kljlHKVWc1jX2g==
=hk7L
-----END PGP MESSAGE-----
YubiKey OpenPGP app configuration:
Reader ...........: Yubico YubiKey OTP FIDO CCID
Application ID ...: D2760001240100000006149158450000
Application type .: OpenPGP
Version ..........: 3.4
Manufacturer .....: Yubico
Serial number ....: 14915845
Name of cardholder: Sun Knudsen
Language prefs ...: en
Salutation .......: 
URL of public key : [not set]
Login data .......: h****@sunknudsen.com
Signature PIN ....: not forced
Key attributes ...: ed25519 cv25519 ed25519
Max. PIN lengths .: 127 127 127
PIN retry counter : 3 0 3
Signature counter : 1
KDF setting ......: off
UIF setting ......: Sign=on Decrypt=on Auth=on
Signature key ....: 944D F65E F0AD 7061 B2FC  05DC 7AF4 09FC 95E7 25EA
      created ....: 2025-12-11 14:59:58
Encryption key....: 6824 24BA ECA4 8BBD D98C  33A9 01F9 0C3C 717E A62D
      created ....: 2025-12-11 14:59:58
Authentication key: E76B CB66 ED83 E130 EB5B  8F51 5C9A D36F 276C 92DD
      created ....: 2025-12-11 14:59:58
General key info..: sub  ed25519/0x7AF409FC95E725EA 2025-12-11 Sun Knudsen <h****@sunknudsen.com>
sec   ed25519/0x96CF76E4301AA4EC  created: 2025-12-11  expires: never     
ssb>  ed25519/0x7AF409FC95E725EA  created: 2025-12-11  expires: 2026-12-11
                                  card-no: 0006 14915845
ssb>  cv25519/0x01F90C3C717EA62D  created: 2025-12-11  expires: 2026-12-11
                                  card-no: 0006 14915845
ssb>  ed25519/0x5C9AD36F276C92DD  created: 2025-12-11  expires: 2026-12-11
                                  card-no: 0006 14915845
YubiKey provisioned
```

### Restore PGP subkeys to YubiKey

```console
$ ./yubikey-prov.sh restore --help
Usage: yubikey-prov.sh restore [options]

Options:
  --secret-keys <path>  Path to PGP secret keys
  --force-sig           Disable GPG agent passphrase caching
  --yes                 Disable confirmation prompts
  -h, --help            Show this help message

$ ./yubikey-prov.sh restore --secret-keys '/Users/sunknudsen/Desktop/sunknudsen-secret-keys.asc'
Importing PGP secret keys…
Trusting imported PGP secret keys…
Parsing PGP secret keys…
Insert YubiKey and press enter
This will factory reset YubiKey OpenPGP app. Do you wish to proceed (y or n)? y
Factory resetting YubiKey OpenPGP app…
Configuring YubiKey OpenPGP app profile…
Configuring YubiKey OpenPGP app subkeys…
Configuring YubiKey OpenPGP app policy…
Configuring YubiKey OpenPGP app user passphrase…
Configuring YubiKey OpenPGP app admin passphrase (press enter to use user passphrase)…
Testing YubiKey OpenPGP app (touch YubiKey)…
-----BEGIN PGP MESSAGE-----

hF4DAfkMPHF+pi0SAQdAkNowj682+YAxddWIdvs1PMD2yTbtlLaRHT4jtUbEtG4w
IWO8iMS9aX4Vr4aSzqUbiPWqEyDkfKL5PO9h1SK4X4kEYPagarwMYPR/8ciVvW4s
1MAHAQkCELTC6D+jAORLwjrYEz4xDYIPcIssYD0qDF7w+JL73E/bUCR3iKtwC3Zb
pN/yC0PNgT0PjRjCKNuH9jZuTFkPbu4/JcwxOUgSYBeYYyn9cHnG6Xw18tgFg/44
9/auZqxtZuUk2KCZ0rN07a/uVnluXVbpERD3qg1qNULQWdMKtl/C0Yferap+XP33
eOEohnyulxl+thnT957UxEz/LPkmi8XSl4DNB9Kk/ZLEwX1/97uCQ1355q7ffvuW
EvlZEAzwAwtbnQ==
=B8C0
-----END PGP MESSAGE-----
YubiKey OpenPGP app configuration:
Reader ...........: Yubico YubiKey OTP FIDO CCID
Application ID ...: D2760001240100000006149158450000
Application type .: OpenPGP
Version ..........: 3.4
Manufacturer .....: Yubico
Serial number ....: 14915845
Name of cardholder: Sun Knudsen
Language prefs ...: en
Salutation .......: 
URL of public key : [not set]
Login data .......: h****@sunknudsen.com
Signature PIN ....: not forced
Key attributes ...: ed25519 cv25519 ed25519
Max. PIN lengths .: 127 127 127
PIN retry counter : 3 0 3
Signature counter : 1
KDF setting ......: off
UIF setting ......: Sign=on Decrypt=on Auth=on
Signature key ....: 944D F65E F0AD 7061 B2FC  05DC 7AF4 09FC 95E7 25EA
      created ....: 2025-12-11 14:59:58
Encryption key....: 6824 24BA ECA4 8BBD D98C  33A9 01F9 0C3C 717E A62D
      created ....: 2025-12-11 14:59:58
Authentication key: E76B CB66 ED83 E130 EB5B  8F51 5C9A D36F 276C 92DD
      created ....: 2025-12-11 14:59:58
General key info..: sub  ed25519/0x7AF409FC95E725EA 2025-12-11 Sun Knudsen <h****@sunknudsen.com>
sec   ed25519/0x96CF76E4301AA4EC  created: 2025-12-11  expires: never     
ssb>  ed25519/0x7AF409FC95E725EA  created: 2025-12-11  expires: 2026-12-11
                                  card-no: 0006 14915845
ssb>  cv25519/0x01F90C3C717EA62D  created: 2025-12-11  expires: 2026-12-11
                                  card-no: 0006 14915845
ssb>  ed25519/0x5C9AD36F276C92DD  created: 2025-12-11  expires: 2026-12-11
                                  card-no: 0006 14915845
YubiKey restored
```

### Extend PGP subkeys expiry

```console
$ ./yubikey-prov.sh extend --help
Usage: yubikey-prov.sh extend [options]

Options:
  --secret-keys <path>  Path to PGP secret keys
  --expiry <expiry>     Subkey expiry (default: "1y")
  -h, --help            Show this help message

$ ./yubikey-prov.sh extend --secret-keys '/Users/sunknudsen/Desktop/sunknudsen-secret-keys.asc'
Importing PGP secret keys…
Trusting imported PGP secret keys…
Extending expiry of PGP subkeys…
Exporting PGP public key…
PGP subkeys expiry extended
```