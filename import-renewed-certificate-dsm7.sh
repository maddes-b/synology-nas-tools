#!/bin/sh -eu
### recommended path: /usr/local/sbin
#/usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.API.Info" method="query" version="1"
#/usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.API.Info" method="query" version="1" query="SYNO.Core.Certificate,SYNO.Core.Certificate."
#/usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.Core.Certificate.CRT" method="list" version="1"
#/usr/syno/synoman/webapi/SYNO.Core.Certificate.lib

### Check parameters
if [ -z "${1:-}" ]; then
  printf -- 'ERROR: Certificate description parameter missing\n'
  return 1 2>/dev/null || exit 1
fi

TARGETSHARE='/volume1/<shared folder>' ## TODO: adapt to system
TARGETDIR="${TARGETSHARE}/tmp/ssl-import/${1}"

### Check run as root
if [ "$(id -u)" -ne 0 ]; then
  printf -- 'ERROR: Not running as root or via sudo\n'
  return 1 2>/dev/null || exit 1
fi

### Determine certificate id for certificate description
CERTID="$(jq -r --arg desc "${1}" 'to_entries[] | select( .value.desc == $desc ) | .key' /usr/syno/etc/certificate/_archive/INFO)"
if [ -z "${CERTID}" ]; then
  printf -- 'ERROR: No certificate ID found for description %s\n' "${1}"
  return 1 2>/dev/null || exit 1
fi

### Check directory for certificate id
CERTDIR="/usr/syno/etc/certificate/_archive/${CERTID}"
if [ ! -d "${CERTDIR}" ]; then
  printf -- 'ERROR: Directory for certificate ID %s does not exist\n' "${CERTID}"
  return 1 2>/dev/null || exit 1
fi

### Check temporary certificate directories
if [ ! -d "${TARGETSHARE}" ]; then
  printf -- 'ERROR: Shared folder %s does not exist\n' "${TARGETSHARE}"
  return 1 2>/dev/null || exit 1
fi
#
if [ ! -d "${TARGETDIR}" ]; then
  printf -- 'ERROR: Temporary certificate folder %s does not exist\n' "${TARGETDIR}"
  return 1 2>/dev/null || exit 1
fi

### Check if certificate was renewed
if [ ! -f "${TARGETDIR}/renewed" ]; then
  return 0 2>/dev/null || exit 0
fi

### Import certificate into DSM via API
/usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.Core.Certificate" method="import" version="1" key_tmp="\"${TARGETDIR}/privkey.pem\"" cert_tmp="\"${TARGETDIR}/cert.pem\"" inter_cert_tmp="\"${TARGETDIR}/chain.pem\"" id="\"${CERTID}\"" desc="\"${1}\""
# optional: as_default="\"true\""

return 0 2>/dev/null || exit 0
