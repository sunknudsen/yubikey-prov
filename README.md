# yubikey-prov

## Provision PGP/YubiKeys

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
  --nfc <nfc>          enabled NFC interfaces (defaults to "FIDO2")
  --usb <usb>          enabled USB interfaces (defaults to "FIDO2 OPENPGP")
  --lock-code <code>   config lock-code (optional)
  --yes                disable confirmation prompts
  -h, --help           display help for command
```

## Contributors

[Sun Knudsen](https://sunknudsen.com/)

## Licence

MIT