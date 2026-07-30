#!/bin/sh
# Offline verification of the print bridge logic: exercises install, printing,
# self-heal, and remote-fix-without-reinstall on a throwaway HOME with the
# macOS-only commands (launchctl/lp/lpstat/cancel) stubbed. Run on any machine:
#   sh verify_local.sh
# Exits non-zero if any assertion fails. This is a dev check, not a CI test.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(mktemp -d)"
export HOME="$ROOT/home"
mkdir -p "$HOME" "$ROOT/stubbin" "$ROOT/rec"
BASE="$HOME/tmp/minds_data/printbridge"; mkdir -p "$BASE/queue"
SUPPORT="$HOME/Library/Application Support/MindsPrintBridge"
PLIST="$HOME/Library/LaunchAgents/com.minds.printbridge.plist"; REC="$ROOT/rec"
cp "$HERE/core.src.sh" "$BASE/core.src.sh"; cp "$HERE/agent.sh" "$BASE/agent.sh"; cp "$HERE/bootstrap.sh" "$BASE/bootstrap.sh"

cat > "$ROOT/stubbin/launchctl" <<EOF
#!/bin/sh
echo "launchctl \$*" >> "$REC/launchctl.calls"; exit 0
EOF
cat > "$ROOT/stubbin/lp" <<EOF
#!/bin/sh
echo "lp \$*" >> "$REC/lp.calls"; echo "request id is Test_Printer-42 (1 file(s))"
EOF
cat > "$ROOT/stubbin/cancel" <<EOF
#!/bin/sh
echo "cancel \$*" >> "$REC/cancel.calls"; echo "cancel ran"
EOF
cat > "$ROOT/stubbin/lpstat" <<EOF
#!/bin/sh
for a in "\$@"; do case "\$a" in -d) echo "system default destination: Test_Printer";; -e) printf "Test_Printer\nOffice_Laser\n";; -p) echo "printer Test_Printer is idle.";; -o) echo "no entries";; esac; done
EOF
chmod +x "$ROOT/stubbin"/*; export PATH="$ROOT/stubbin:$PATH"

pass=0; fail=0
chk(){ if eval "$2"; then echo "PASS: $1"; pass=$((pass+1)); else echo "FAIL: $1"; fail=$((fail+1)); fi; }

/bin/sh "$BASE/agent.sh" >/dev/null 2>&1
chk "durable core == shipped core.src.sh" "diff -q '$HERE/core.src.sh' '$SUPPORT/core.sh' >/dev/null"
/bin/sh "$BASE/bootstrap.sh" >/dev/null 2>&1
chk "install: launcher parses" "python3 -c \"import plistlib;plistlib.load(open('$PLIST','rb'))\""
chk "install: receipt loaded" "grep -q 'agent_status: loaded' '$BASE/install-receipt.txt'"
: > "$REC/lp.calls"; printf '%%PDF\n' > "$BASE/queue/t.pdf"; /bin/sh "$SUPPORT/core.sh"
chk "print via launchd target" "grep -q 'lp -d Test_Printer .*t.pdf' '$REC/lp.calls' && grep -q Test_Printer-42 '$BASE/receipts/t.pdf.txt'"
rm -rf "$HOME/tmp/minds_data"; /bin/sh "$SUPPORT/core.sh"
: > "$REC/lp.calls"; printf 'x\n' > "$BASE/queue/aw.pdf"; /bin/sh "$SUPPORT/core.sh"
chk "self-heal full folder wipe + prints" "grep -q 'aw.pdf' '$REC/lp.calls'"
rm -f "$PLIST"; /bin/sh "$SUPPORT/core.sh"
chk "self-heal deleted launcher" "python3 -c \"import plistlib;plistlib.load(open('$PLIST','rb'))\""
printf '#!/bin/sh\necho bug > %s/LOGIC_BUG\n' "$BASE" > "$BASE/agent.sh"
: > "$REC/lp.calls"; printf 'x\n' > "$BASE/queue/j.pdf"; /bin/sh "$SUPPORT/core.sh"
chk "shipped logic bug: no print" "[ ! -s '$REC/lp.calls' ] && [ -f '$BASE/LOGIC_BUG' ]"
cp "$HERE/agent.sh" "$BASE/agent.sh"; /bin/sh "$SUPPORT/core.sh"
chk "remote logic fix -> prints (no reinstall)" "grep -q 'j.pdf' '$REC/lp.calls'"
sed '1a echo CORE_BUG > '"$BASE"'/CORE_BUG' "$SUPPORT/core.sh" > "$SUPPORT/c.tmp" && mv "$SUPPORT/c.tmp" "$SUPPORT/core.sh"
/bin/sh "$SUPPORT/core.sh"; rm -f "$BASE/CORE_BUG"; /bin/sh "$SUPPORT/core.sh"
chk "remote fix -> durable core canonical (bug gone)" "diff -q '$HERE/core.src.sh' '$SUPPORT/core.sh' >/dev/null && [ ! -f '$BASE/CORE_BUG' ]"
sed 's/<integer>15<\/integer>/<integer>999<\/integer>/' "$PLIST" > "$PLIST.t" && mv "$PLIST.t" "$PLIST"
/bin/sh "$SUPPORT/core.sh"
chk "remote fix -> launcher canonical (15, not 999)" "grep -q '<integer>15</integer>' '$PLIST' && ! grep -q 999 '$PLIST'"

echo "TOTAL: pass=$pass fail=$fail"
rm -rf "$ROOT"
[ "$fail" -eq 0 ]
