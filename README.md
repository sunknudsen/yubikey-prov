# yubikey-prov

## Provision PGP/YubiKeys securely (beta)

This project was developed to [securely](#security-features) provision PGP/YubiKeys at “enterprise” scale.

The [yubikey-prov.sh](./yubikey-prov.sh) script automates as much of [How to generate and air gap PGP private keys using GnuPG, Tails and YubiKey](https://sunknudsen.com/privacy-guides/how-to-generate-and-air-gap-pgp-private-keys-using-gnupg-tails-and-yubikey) as possible without compromising on security.

Although script works on macOS Catalina and Big Sur (for development purposes), it is **highly** recommended to use script on [Tails](https://tails.boum.org/).

**Shout-out to [TrustToken](https://www.trusttoken.com/) for supporting project. 🙌**

## Security features

- Uses [Tails](https://tails.boum.org/) to generate PGP keys (using [GnuPG](https://gnupg.org/)) on air-gapped, amnesic and hardened operating system
- Uses [VeraCrypt](https://www.veracrypt.fr/en/Home.html) to backup PGP master keys and subkeys
- Uses [YubiKeys](https://www.yubico.com/) to secure subkeys

## Requirements

- [Tails USB flash drive or SD card](https://sunknudsen.com/privacy-guides/how-to-install-tails-on-usb-flash-drive-or-sd-card-on-macos) with [VeraCrypt](https://sunknudsen.com/privacy-guides/how-to-install-and-use-veracrypt-on-tails) and [YubiKey Manager](https://sunknudsen.com/privacy-guides/how-to-generate-and-air-gap-pgp-private-keys-using-gnupg-tails-and-yubikey#step-3-import-dennis-fokins-and-emil-lundbergs-pgp-public-keys-used-to-verify-downloads-below) installed
- VeraCrypt encrypted volume stored on USB flash drive or SD card at path `/Volumes/Data/tails`
- YubiKey with [OpenPGP](https://www.yubico.com/us/store/compare/) support (firmware version 5.2.3 or higher)

## Installation (on Tails)

```shell
cd ~/Persistent
git clone https://github.com/sunknudsen/yubikey-prov.git
cd yubikey-prov
```

## Usage

```console
$ ./yubikey-prov.sh --help
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

## Example

Create PGP master key and signing, encryption and authentication subkeys, sign pub key using signing key, backup keys to VeraCrypt encrypted volume and pub key to public folder, move subkeys to YubiKey, disable all YubiKey NFC/USB interfaces except FIDO2 and OpenPGP, enable YubiKey user interaction and set user and admin PINs.

```console
$ yubikey-prov.sh --first-name "John" --last-name "Doe" --email "john@example.net" --signing-key "/media/veracrypt/PGP/signingkey.asc"
```

## Contributors

[Sun Knudsen](https://sunknudsen.com/)

## Licence

MIT