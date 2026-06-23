#!/usr/bin/env bash
#
# Tests for scripts/display-restore.sh
#
# These tests stub `displayplacer` and `betterdisplaycli` with fake
# executables on PATH so the restore script's behavior can be verified
# without any real display hardware. Each stub appends its invocation to
# $CALL_LOG so tests can assert what was called and in what order.
#
# Run:  bash tests/restore_test.sh
#
set -uo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$THIS_DIR/.." && pwd)"
RESTORE="$ROOT_DIR/scripts/display-restore.sh"

PASS=0
FAIL=0

fail() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }
ok()   { printf '  ok:   %s\n' "$1"; PASS=$((PASS + 1)); }

# Build an isolated test workspace with stub binaries on PATH.
# Args: $1 = "present" | "absent"  (whether the physical display enumerates)
make_workspace() {
  local physical_state="$1"
  WORK="$(mktemp -d)"
  BIN="$WORK/bin"
  mkdir -p "$BIN"
  CALL_LOG="$WORK/calls.log"
  : >"$CALL_LOG"

  # Layout the restore script will be asked to apply: physical Studio
  # Display at 3200x1800, with a virtual-discard directive.
  LAYOUT="$WORK/local.displayplacer"
  cat >"$LAYOUT" <<'EOF'
# betterdisplay-discard: --type=VirtualScreen --name=ScreensRemote
displayplacer "id:s1879776955 res:3200x1800 hz:60 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0"
EOF

  # `displayplacer list` output when the physical display is present. Its
  # trailing command differs from the requested layout (1920x1080 vs
  # 3200x1800) so the script does not short-circuit as "already applied".
  cat >"$WORK/list_present.txt" <<'EOF'
Persistent screen id: 61CFBB31-9AA0-466A-99CB-96BF2E04853E
Serial screen id: s1879776955
Type: 27 inch external screen
Resolution: 1920x1080
Scaling: on
Enabled: true
displayplacer "id:s1879776955 res:1920x1080 hz:60 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0"
EOF

  # `displayplacer list` output when only the virtual remains (physical gone).
  cat >"$WORK/list_absent.txt" <<'EOF'
Persistent screen id: F700DBCB-D208-4ED4-B006-A083B845E2F7
Serial screen id: s313775617
Type: 24 inch external screen
Resolution: 1920x1080
Scaling: on
Enabled: true
displayplacer "id:954B67AB-688F-4BC2-87EB-C7D8409EA2ED res:1920x1080 hz:60 color_depth:4 enabled:true scaling:on origin:(0,0) degree:0"
EOF

  if [[ "$physical_state" == "present" ]]; then
    cp "$WORK/list_present.txt" "$WORK/list_active.txt"
  else
    cp "$WORK/list_absent.txt" "$WORK/list_active.txt"
  fi

  cat >"$BIN/displayplacer" <<EOF
#!/usr/bin/env bash
echo "displayplacer \$*" >>"$CALL_LOG"
if [[ "\${1:-}" == "list" ]]; then
  cat "$WORK/list_active.txt"
  exit 0
fi
# Anything else is an apply; succeed.
echo "applied \$*"
exit 0
EOF

  cat >"$BIN/betterdisplaycli" <<EOF
#!/usr/bin/env bash
echo "betterdisplaycli \$*" >>"$CALL_LOG"
case "\${1:-}" in
  discard)
    # Succeed once, then report nothing-left so the discard loop ends.
    cnt="$WORK/discard_count"
    n=\$(cat "\$cnt" 2>/dev/null || echo 0); n=\$((n + 1)); echo "\$n" >"\$cnt"
    [[ "\$n" -le 1 ]] && exit 0 || exit 1
    ;;
  *) exit 0 ;;
esac
EOF

  chmod +x "$BIN/displayplacer" "$BIN/betterdisplaycli"
}

run_restore() {
  # Fast reconnect retries so the "absent" path doesn't sleep for real.
  PATH="$BIN:$PATH" RESTORE_RECONNECT_RETRIES=1 RESTORE_RECONNECT_WAIT=0 \
    DISPLAY_SWITCHER_DIAG_DIR="$WORK/diagnostics" \
    bash "$RESTORE" "$LAYOUT" >"$WORK/stdout.txt" 2>"$WORK/stderr.txt"
  echo $?
}

line_of() { grep -n "$1" "$CALL_LOG" 2>/dev/null | head -n1 | cut -d: -f1; }

cleanup() { [[ -n "${WORK:-}" && -d "$WORK" ]] && rm -rf "$WORK"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
echo "Test 1: discard runs BEFORE apply"
make_workspace present
rc="$(run_restore)"
discard_line="$(line_of 'betterdisplaycli discard')"
apply_line="$(line_of 'res:3200x1800')"
if [[ -n "$discard_line" && -n "$apply_line" && "$discard_line" -lt "$apply_line" ]]; then
  ok "discard (line $discard_line) precedes apply (line $apply_line)"
else
  fail "expected discard before apply (discard=$discard_line apply=$apply_line, rc=$rc)"
fi
cleanup

# ---------------------------------------------------------------------------
echo "Test 2: missing physical display triggers a reconnect attempt"
make_workspace absent
rc="$(run_restore)"
if grep -q 'betterdisplaycli perform --connectAllDisplays' "$CALL_LOG"; then
  ok "called connectAllDisplays when physical display absent"
else
  fail "expected connectAllDisplays reconnect attempt (rc=$rc)"
fi
cleanup

# ---------------------------------------------------------------------------
echo "Test 3: physical still missing prints hardware guidance and fails"
make_workspace absent
rc="$(run_restore)"
if [[ "$rc" -ne 0 ]] && grep -qiE 'edid|cable|power-cycle|thunderbolt|port' "$WORK/stderr.txt"; then
  ok "exited nonzero ($rc) with hardware guidance"
else
  fail "expected nonzero exit + EDID/cable guidance (rc=$rc); stderr: $(cat "$WORK/stderr.txt")"
fi
# And it should NOT have tried to apply the layout into a missing display.
if grep -q 'res:3200x1800' "$CALL_LOG"; then
  fail "should not attempt apply when physical display is absent"
else
  ok "did not attempt apply with physical display absent"
fi
cleanup

# ---------------------------------------------------------------------------
echo "Test 4: happy path applies the layout and exits 0"
make_workspace present
rc="$(run_restore)"
if [[ "$rc" -eq 0 ]] && grep -q 'res:3200x1800' "$CALL_LOG"; then
  ok "applied layout, exit 0"
else
  fail "expected apply + exit 0 (rc=$rc); stderr: $(cat "$WORK/stderr.txt")"
fi
cleanup

# ---------------------------------------------------------------------------
echo "Test 5: already-restored serial-id layout is a true no-op"
make_workspace present
cp "$WORK/list_present.txt" "$WORK/list_active.txt"
sed -i '' 's/Resolution: 1920x1080/Resolution: 3200x1800/' "$WORK/list_active.txt"
rc="$(run_restore)"
if [[ "$rc" -eq 0 ]] && grep -q 'Already at requested local display layout' "$WORK/stdout.txt"; then
  ok "recognized equivalent serial-id layout"
else
  fail "expected semantic no-op detection (rc=$rc)"
fi
if grep -q 'res:3200x1800' "$CALL_LOG"; then
  fail "should not apply displayplacer for an equivalent layout"
else
  ok "did not reapply an equivalent display mode"
fi
cleanup

# ---------------------------------------------------------------------------
echo "Test 6: invocation diagnostics are recorded"
make_workspace present
rc="$(run_restore)"
if [[ -s "$WORK/diagnostics/events.log" ]] \
  && grep -q 'action=restore' "$WORK/diagnostics/events.log" \
  && grep -q 'phase=end' "$WORK/diagnostics/events.log"; then
  ok "recorded restore begin/end diagnostics"
else
  fail "expected invocation diagnostics (rc=$rc)"
fi
cleanup

# ---------------------------------------------------------------------------
echo
echo "Passed: $PASS  Failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
