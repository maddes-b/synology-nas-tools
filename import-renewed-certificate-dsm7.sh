#!/bin/sh -eu
### recommended path: /usr/local/sbin
### https://kb.synology.com/en-us/DSM/tutorial/common_mistake_in_task_scheduler_script
### /usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.API.Info" method="query" version="1"
### /usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.API.Info" method="query" version="1" query="\"SYNO.Core.Certificate,SYNO.Core.Certificate.\""
### /usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.Core.Certificate.CRT" method="list" version="1"
### /usr/bin/jq . /usr/syno/synoman/webapi/SYNO.Core.Certificate.lib
### Exit codes:
### * 0 = all good, no errors
### - 10 = all good, certificate imported; use ${?} to output any notification
### * see glibc: https://sourceware.org/git/?p=glibc.git;a=blob;f=misc/sysexits.h;hb=HEAD
### * see https://tldp.org/LDP/abs/html/exitcodes.html

SCRIPTNAME="$(basename "${0}")"

## Check parameters
if [ -z "${1:-}" -o -z "${2:-}" ]; then
  printf -- '%s\n' \
    "ERROR/${SCRIPTNAME}: Missing parameter(s)" \
    "Usage: ${0} </path/to/tmp/cert> <cert description>"
  return 64 2>/dev/null || exit 64
fi
#
CERTTMPPATH="${1}"
CERTDESC="${2}"

## Check run as root
if [ "$(id -u)" -ne 0 ]; then
  printf -- '%s\n' \
    "ERROR/${SCRIPTNAME}: Not running as root or via sudo"
  return 77 2>/dev/null || exit 77
fi

## Determine certificate id for certificate description
CERTID="$(/usr/bin/jq -r --arg desc "${CERTDESC}" 'to_entries[] | select( .value.desc == $desc ) | .key' /usr/syno/etc/certificate/_archive/INFO)"
if [ -z "${CERTID}" ]; then
  printf -- '%s\n' \
    "ERROR/${SCRIPTNAME}: No certificate ID found for description ${CERTDESC}"
  return 65 2>/dev/null || exit 65
fi

## Check directory for certificate id
CERTDIR="/usr/syno/etc/certificate/_archive/${CERTID}"
if [ ! -d "${CERTDIR}" ]; then
  printf -- '%s\n' \
    "ERROR/${SCRIPTNAME}: Directory for certificate ID ${CERTID} does not exist"
  return 72 2>/dev/null || exit 72
fi

## Check temporary certificate directory
if [ ! -d "${CERTTMPPATH}" ]; then
  printf -- '%s\n' \
    "ERROR/${SCRIPTNAME}: Temporary certificate folder ${CERTTMPPATH} does not exist"
  return 66 2>/dev/null || exit 66
fi

## Check if certificate was renewed
if [ ! -f "${CERTTMPPATH}/renewed" ]; then
  return 0 2>/dev/null || exit 0
fi

## Import certificate into DSM via API
RESULT="$(/usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.Core.Certificate" method="import" version="1" key_tmp="\"${CERTTMPPATH}/privkey.pem\"" cert_tmp="\"${CERTTMPPATH}/cert.pem\"" inter_cert_tmp="\"${CERTTMPPATH}/chain.pem\"" id="\"${CERTID}\"" desc="\"${CERTDESC}\"")"
# optional: as_default="\"true\""
printf -- "${RESULT}\n"

## Check json result and error out if not successful
SUCCESS="$(printf -- "${RESULT}" | /usr/bin/jq -r '.success' )"
if [ "${SUCCESS}" != 'true' ]; then
  return 73 2>/dev/null || exit 73
fi

rm "${CERTTMPPATH}/renewed"

return 10 2>/dev/null || exit 10
