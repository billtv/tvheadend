#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2023 Olliver Schinagl <oliver@schinagl.nl>
#
# A beginning user should be able to docker run image bash (or sh) without
# needing to learn about --entrypoint
# https://github.com/docker-library/official-images#consistency

set -eu

bin='tvheadend'
config_dir="${TVH_CONFIG_DIR:-/config}"
recordings_dir="${TVH_RECORDINGS_DIR:-/recordings}"
run_user="${PUID:-}"
run_group="${PGID:-}"

# run command if it is not starting with a "-" and is an executable in PATH
if [ "${#}" -le 0 ] || \
   [ "${1#-}" != "${1}" ] || \
   [ -d "${1}" ] || \
   ! command -v "${1}" > '/dev/null' 2>&1; then
  entrypoint='true'
fi

if [ -n "${entrypoint:-}" ]; then
  if [ -n "${RUN_OPTS:-}" ]; then
    # shellcheck disable=SC2086
    set -- ${RUN_OPTS} "$@"
  fi

  if [ -d "${config_dir}" ]; then
    set -- --config "${config_dir}" "$@"
  fi

  if [ "$(id -u)" = '0' ]; then
    if [ -d "${recordings_dir}" ]; then
      default_recordings_dir='/var/lib/tvheadend/recordings'
      if [ "${recordings_dir}" != "${default_recordings_dir}" ]; then
        if [ -L "${default_recordings_dir}" ]; then
          rm -f "${default_recordings_dir}"
        elif [ -d "${default_recordings_dir}" ]; then
          rmdir "${default_recordings_dir}" 2>/dev/null || true
        fi

        if [ ! -e "${default_recordings_dir}" ]; then
          ln -s "${recordings_dir}" "${default_recordings_dir}"
        fi
      fi
    fi

    if [ -n "${run_user}" ] || [ -n "${run_group}" ]; then
      run_user="${run_user:-$(id -u tvheadend 2>/dev/null || echo 1000)}"
      run_group="${run_group:-$(id -g tvheadend 2>/dev/null || echo 1000)}"
    else
      run_user='tvheadend'
      run_group='tvheadend'
    fi

    for dir in "${config_dir}" "${recordings_dir}" '/var/lib/tvheadend' '/var/log/tvheadend'; do
      if [ -e "${dir}" ]; then
        chown -R "${run_user}:${run_group}" "${dir}" 2>/dev/null || true
      fi
    done

    if command -v su-exec > '/dev/null' 2>&1; then
      exec su-exec "${run_user}:${run_group}" ${bin:?} "$@"
    fi
    if command -v gosu > '/dev/null' 2>&1; then
      exec gosu "${run_user}:${run_group}" ${bin:?} "$@"
    fi
  fi
fi

exec ${entrypoint:+${bin:?}} "$@"

exit 0
