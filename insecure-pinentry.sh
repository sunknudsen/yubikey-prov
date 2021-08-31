#!/bin/bash
# This approach is insecure but the only workaround one has currently.
# See https://dev.gnupg.org/T5575 and https://security.stackexchange.com/q/254757

if [ -z "$PINENTRY_USER_DATA" ]; then
  echo "Missing PINENTRY_USER_DATA"
  exit 1
fi

_IFS=IFS
IFS="," user_data=($PINENTRY_USER_DATA)
IFS=_IFS

echo "OK"

while IFS='$\n' read -r line; do
  if [[ "$line" =~ ^SETDESC[[:space:]]Please[[:space:]]enter[[:space:]]the([[:space:]]Admin)?[[:space:]]PIN ]]; then
    pin=true
  elif [[ "$line" =~ ^SETDESC[[:space:]]New([[:space:]]Admin)?[[:space:]]PIN ]] || [[ "$line" =~ ^SETDESC[[:space:]]Repeat[[:space:]]this[[:space:]]PIN ]]; then
    new_pin=true
  elif [[ "$line" = "GETPIN" ]]; then
    if [ "$pin" = true ]; then
      echo "D ${user_data[0]}"
    elif [ "$new_pin" = true ]; then
      echo "D ${user_data[1]}"
    fi
  fi
  echo "OK"
done