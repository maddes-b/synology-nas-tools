#!/bin/sh -eu
### recommended path: /usr/local/sbin
### https://kb.synology.com/en-us/DSM/tutorial/common_mistake_in_task_scheduler_script
### /usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.API.Info" method="query" version="1"
### /usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.API.Info" method="query" version="1" query="\"SYNO.Core.TaskScheduler,SYNO.Core.TaskScheduler.\""
### /usr/bin/jq . /usr/syno/synoman/webapi/SYNO.Core.TaskScheduler.lib
### Exit codes:
### * 0 = all good, no errors
### * see glibc: https://sourceware.org/git/?p=glibc.git;a=blob;f=misc/sysexits.h;hb=HEAD
### * see https://tldp.org/LDP/abs/html/exitcodes.html

SCRIPTNAME="$(basename "${0}")"

## Check parameters
if [ -z "${1:-}" -o -z "${2:-}" ]; then
  printf -- '%s\n' \
    "ERROR/${SCRIPTNAME}: Missing parameter(s)" \
    "Usage: ${0} <task name> <enable:true|false>"
  return 64 2>/dev/null || exit 64
fi
#
TASKNAME="${1}"
ENABLE="$(printf -- '%s' "${2}" | sed 's#.*#\L&#')"
#
case "${ENABLE}" in
 ("false"|"true") ;;
 (*)
  printf -- '%s\n' \
    "ERROR/${SCRIPTNAME}: Invalid enable parameter" \
    "Usage: ${0} <task name> <enable:true|false>"
  return 64 2>/dev/null || exit 64
  ;;
esac

## Determine task id for task name
TASKID="$(/usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.Core.TaskScheduler" method="list" version="3" | /usr/bin/jq -r --arg name "${TASKNAME}" '.data.tasks[] | select( .name == $name ) | .id')"
if [ -z "${TASKID}" ]; then
  printf -- '%s\n' \
    "ERROR/${SCRIPTNAME}: No task ID found for name ${TASKNAME}"
  return 65 2>/dev/null || exit 65
fi

## set enable status for task via API
RESULT="$(/usr/syno/bin/synowebapi --exec-fastwebapi api="SYNO.Core.TaskScheduler" method="set_enable" version="2" status="[{\"id\":${TASKID},\"enable\":${ENABLE}}]")"
printf -- "${RESULT}\n"

## Check json result and error out if not successful
SUCCESS="$(printf -- "${RESULT}" | /usr/bin/jq -r '.success' )"
if [ "${SUCCESS}" != 'true' ]; then
  return 70 2>/dev/null || exit 70
fi

return 0 2>/dev/null || exit 0
