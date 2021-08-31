# yubikey-prov

## Provision PGP/YubiKeys

This project was developed to securely provision and backup PGP keys and move subkeys to hardened YubiKey.

## Installation

```shell
git clone https://github.com/sunknudsen/yubikey-prov.git
cd yubikey-prov
```

## Usage

```console
$ yubikey-prov.sh --help
Usage: yubikey-prov.sh [options]

Options:
  --first-name <name>  first name
  --last-name <name>   last name
  --email <email>      email
  --expiry <expiry>    subkey expiry (defaults to 1)
  --signing-key <path> sign public key using signing key (optional)
  --nfc <nfc>          enable NFC interfaces (defaults to "FIDO2")
  --usb <usb>          enable USB interfaces (defaults to "FIDO2 OPENPGP")
  --lock-code <code>   set lock-code (optional)
  --yes                disable confirmation prompts
  -h, --help           display help for command
```

## Contributors

[Sun Knudsen](https://sunknudsen.com/)

## Licence

MIT