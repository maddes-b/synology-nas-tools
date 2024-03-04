#!/bin/sh -eu
### recommended path: /usr/local/sbin
### https://kb.synology.com/en-us/DSM/tutorial/common_mistake_in_task_scheduler_script
### /usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.API.Info" method="query" version="1"
### /usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.API.Info" method="query" version="1" query="SYNO.Core.Certificate,SYNO.Core.Certificate."
### /usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.Core.Certificate.CRT" method="list" version="1"
### /usr/syno/synoman/webapi/SYNO.Core.Certificate.lib

## Check parameters
if [ -z "${1:-}" -o -z "${2:-}" ]; then
  printf -- '%s\n' \
    'ERROR: Missing parameter(s)' \
    "Usage: ${0} </path/to/tmp/cert> <cert description>"
  return 1 2>/dev/null || exit 1
fi
#
CERTTMPPATH="${1}"
CERTDESC="${2}"

## Check run as root
if [ "$(id -u)" -ne 0 ]; then
  printf -- 'ERROR: Not running as root or via sudo\n'
  return 1 2>/dev/null || exit 1
fi

## Determine certificate id for certificate description
CERTID="$(/usr/bin/jq -r --arg desc "${CERTDESC}" 'to_entries[] | select( .value.desc == $desc ) | .key' /usr/syno/etc/certificate/_archive/INFO)"
if [ -z "${CERTID}" ]; then
  printf -- 'ERROR: No certificate ID found for description %s\n' "${CERTDESC}"
  return 1 2>/dev/null || exit 1
fi

## Check directory for certificate id
CERTDIR="/usr/syno/etc/certificate/_archive/${CERTID}"
if [ ! -d "${CERTDIR}" ]; then
  printf -- 'ERROR: Directory for certificate ID %s does not exist\n' "${CERTID}"
  return 1 2>/dev/null || exit 1
fi

## Check temporary certificate directory
if [ ! -d "${CERTTMPPATH}" ]; then
  printf -- 'ERROR: Temporary certificate folder %s does not exist\n' "${CERTTMPPATH}"
  return 1 2>/dev/null || exit 1
fi

## Check if certificate was renewed
if [ ! -f "${CERTTMPPATH}/renewed" ]; then
  return 0 2>/dev/null || exit 0
fi

## Import certificate into DSM via API
/usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.Core.Certificate" method="import" version="1" key_tmp="\"${CERTTMPPATH}/privkey.pem\"" cert_tmp="\"${CERTTMPPATH}/cert.pem\"" inter_cert_tmp="\"${CERTTMPPATH}/chain.pem\"" id="\"${CERTID}\"" desc="\"${CERTDESC}\""
# optional: as_default="\"true\""

## TODO: check result and error out

rm "${CERTTMPPATH}/renewed"

return 0 2>/dev/null || exit 0
