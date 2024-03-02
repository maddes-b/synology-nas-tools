#!/bin/sh -eu
### Workaround script as DSM 7 does not support IPv6 multi-homing as by design (2024-03: 7.2.1-Update 4)
### https://community.synology.com/enu/forum/1/post/186660

### Avoid running in parallel (e.g. running each minute)
PID_FILE='/run/fix-ipv6-addresses-dsm7.pid'
if [ -s "${PID_FILE}" ]; then
  PID="$(head -qn 1 "${PID_FILE}")"
  if [ -d "/proc/${PID}" ]; then
    RUNNING=0
    CMDLINE="$(xargs -0 -I % printf -- "%\n" </proc/"${PID}"/cmdline)"
    printf -- "${CMDLINE}" | while read ARGUMENT
     do
      if [ "${ARGUMENT}" == "${0}" ]; then
        RUNNING=1
        break
      fi
    done
    if [ "${RUNNING}" -ne 0 ]; then
      return 0 2>/dev/null || exit 0
    fi
  fi ## /proc/PID
fi ## PID_FILE
#
printf -- '%s' "${$}" >"${PID_FILE}"

### Variables and function to log that fixing took place
LOG_DIR='/volume1/<shared folder>/path/to/log' ## TODO: adapt to system
LOG_FILE="${LOG_DIR}/ipv6_fixed.log"
if [ -d "${LOG_DIR}" ]; then
  LOG_LINE="$(date -Iseconds)${1:+ ${1}}"
  LOG_DONE=0
else
  LOG_DONE=1
fi

log_fixed () {
  if [ "${LOG_DONE}" -eq 0 ]; then
    printf -- '%s\n' "${LOG_LINE}" >>"${LOG_FILE}"
    LOG_DONE=1
  fi
}

### Variables definitions
INTERFACE='ovs_bond0' ## TODO: adapt to system
NEED_DHCPC=0
NEED_RA=0
#
PREFIX_ULA1='fdxxxxxxxxxxxxxx' ## TODO: adapt to network
PREFIX_GUA='2003'

### Check sysctl settings: addr_gen_mode (not on DSM7 kernel), use_tempaddr, accept_ra_defrtr, accept_ra_pinfo, accept_ra
## https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt
#SYSCTL="$(sysctl -n "net.ipv6.conf.${INTERFACE}.addr_gen_mode")"
#if [ "${SYSCTL}" -ne 0 ]; then
#  # Don't do stable prefix addresses
#  log_fixed
#  printf -- "ERROR: addr_gen_mode not 0 on ${INTERFACE}\n"
#  sysctl "net.ipv6.conf.${INTERFACE}.addr_gen_mode"
#  sysctl -w "net.ipv6.conf.${INTERFACE}.addr_gen_mode=0"
#  NEED_RA=1
#fi
#
SYSCTL="$(sysctl -n "net.ipv6.conf.${INTERFACE}.use_tempaddr")"
if [ "${SYSCTL}" -ne 2 ]; then
  log_fixed
  printf -- "ERROR: use_tempaddr not 2 on ${INTERFACE}\n"
  sysctl "net.ipv6.conf.${INTERFACE}.use_tempaddr"
  sysctl -w "net.ipv6.conf.${INTERFACE}.use_tempaddr=2"
  NEED_RA=1
fi
#
SYSCTL="$(sysctl -n "net.ipv6.conf.${INTERFACE}.accept_ra_defrtr")"
if [ "${SYSCTL}" -ne 1 ]; then
  log_fixed
  printf -- "ERROR: accept_ra_defrtr not 1 on ${INTERFACE}\n"
  sysctl "net.ipv6.conf.${INTERFACE}.accept_ra_defrtr"
  sysctl -w "net.ipv6.conf.${INTERFACE}.accept_ra_defrtr=1"
  NEED_RA=1
fi
#
SYSCTL="$(sysctl -n "net.ipv6.conf.${INTERFACE}.accept_ra_pinfo")"
if [ "${SYSCTL}" -ne 1 ]; then
  log_fixed
  printf -- "ERROR: accept_ra_pinfo not 1 on ${INTERFACE}\n"
  sysctl "net.ipv6.conf.${INTERFACE}.accept_ra_pinfo"
  sysctl -w "net.ipv6.conf.${INTERFACE}.accept_ra_pinfo=1"
  NEED_RA=1
fi
#
SYSCTL="$(sysctl -n "net.ipv6.conf.${INTERFACE}.accept_ra")"
if [ "${SYSCTL}" -ne 2 ]; then
  log_fixed
  printf -- "ERROR: accept_ra not 2 on ${INTERFACE}\n"
  sysctl "net.ipv6.conf.${INTERFACE}.accept_ra"
  sysctl -w "net.ipv6.conf.${INTERFACE}.accept_ra=2"
  NEED_RA=1
fi

### Check for ULA #1 (DHPCv6)
RC=0
grep -q -e "^${PREFIX_ULA1}.*${INTERFACE}\$" /proc/net/if_inet6 || RC="${?}"
if [ "${RC}" -ne 0 ]; then
  log_fixed
  printf -- "ERROR: ULA with prefix ${PREFIX_ULA1} missing on ${INTERFACE}\n"
  NEED_DHCPC=1
fi

### Check for GUA (SLAAC)
RC=0
grep -q -e "^${PREFIX_GUA}.*${INTERFACE}\$" /proc/net/if_inet6 || RC="${?}"
if [ "${RC}" -ne 0 ]; then
  log_fixed
  printf -- "ERROR: GUA missing on ${INTERFACE}\n"
  NEED_RA=1
fi

### Check for default route
ROUTE="$(ip -6 route show match default)"
if [ -z "${ROUTE}" ]; then
  log_fixed
  printf -- "ERROR: default route missing\n"
  NEED_RA=1
fi

### Try to get IPv6 addresses
if [ "${NEED_DHCPC}" -ne 0 -o "${NEED_RA}" -ne 0 ]; then
  /sbin/ip -6 addr show dev "${INTERFACE}"
  #
  if [ "${NEED_DHCPC}" -ne 0 ]; then
    /usr/syno/bin/synosystemctl enable "dhclient6@${INTERFACE}-client.service"
    /usr/syno/bin/synosystemctl start "dhclient6@${INTERFACE}-client.service"
  fi
  #
  if [ "${NEED_RA}" -ne 0 ]; then
    /sbin/rdisc6 -mnq "${INTERFACE}"
  fi
  #
  /sbin/ip -6 addr show dev "${INTERFACE}"
  ip -6 route show match default
fi

rm "${PID_FILE}"

return 0 2>/dev/null || exit 0
