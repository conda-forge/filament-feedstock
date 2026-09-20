#!/usr/bin/env bash
set -euo pipefail

test_executable="${1:?usage: run_wayland_test.sh TEST_EXECUTABLE}"
lavapipe_icd=/usr/share/vulkan/icd.d/lvp_icd.x86_64.json
if [[ ! -f "${lavapipe_icd}" ]]; then
  echo "missing Wayland-enabled system lavapipe ICD: ${lavapipe_icd}" >&2
  exit 1
fi
runtime_dir=$(mktemp -d)
chmod 700 "${runtime_dir}"
export XDG_RUNTIME_DIR="${runtime_dir}"
export WAYLAND_DISPLAY=wayland-filament-test

weston --backend=headless --renderer=pixman --no-config --idle-time=0 \
  --socket="${WAYLAND_DISPLAY}" --log="${PWD}/weston.log" &
weston_pid=$!

cleanup() {
  kill "${weston_pid}" 2>/dev/null || true
  wait "${weston_pid}" 2>/dev/null || true
  rm -rf "${runtime_dir}"
}
trap cleanup EXIT

for _ in {1..100}; do
  if [[ -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]]; then
    VK_DRIVER_FILES="${lavapipe_icd}" \
      "${test_executable}"
    exit
  fi
  if ! kill -0 "${weston_pid}" 2>/dev/null; then
    cat "${PWD}/weston.log"
    exit 1
  fi
  sleep 0.1
done

cat "${PWD}/weston.log"
exit 1
