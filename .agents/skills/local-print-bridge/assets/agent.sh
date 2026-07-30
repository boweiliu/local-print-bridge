#!/bin/sh
# Minds Print Bridge -- the editable logic (source of truth). Lives in the bridge
# folder, so the mind can rewrite it remotely. On every run it (1) rewrites the
# durable core, the launcher, and its own durable backup from itself -- so fixing
# a bug here fixes ALL copies on the next tick -- then (2) runs any one-shot
# maintenance commands dropped in cmd/, and (3) prints anything queued.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
LABEL="com.minds.printbridge"
SUPPORT="$HOME/Library/Application Support/MindsPrintBridge"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BASE="$HOME/tmp/minds_data/printbridge"
QUEUE="$BASE/queue"; DONE="$BASE/done"; RECEIPTS="$BASE/receipts"
CMD="$BASE/cmd"; CMDDONE="$BASE/cmd_done"
mkdir -p "$QUEUE" "$DONE" "$RECEIPTS" "$CMD" "$CMDDONE" "$SUPPORT" "$HOME/Library/LaunchAgents"

# ---- keep every durable copy in sync with THIS file (remote self-repair) ----
cp "$BASE/agent.sh" "$SUPPORT/agent.default.sh" 2>/dev/null

cat > "$SUPPORT/core.sh" <<'CORE'
#!/bin/sh
# Minds Print Bridge -- durable core (the ONLY fixed-in-place piece).
# Deliberately minimal: restore the editable logic if the bridge folder was wiped,
# then run it. All real work + all self-updating lives in agent.sh, which the mind
# can edit through the file bridge -- so a mistake anywhere else is fixable remotely.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
SUPPORT="$HOME/Library/Application Support/MindsPrintBridge"
BASE="$HOME/tmp/minds_data/printbridge"
mkdir -p "$BASE/queue" "$BASE/done" "$BASE/receipts" "$SUPPORT"
[ -f "$BASE/agent.sh" ] || { [ -f "$SUPPORT/agent.default.sh" ] && cp "$SUPPORT/agent.default.sh" "$BASE/agent.sh"; }
[ -f "$BASE/agent.sh" ] && exec /bin/sh "$BASE/agent.sh"
exit 0
CORE

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/sh</string><string>$SUPPORT/core.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>15</integer>
  <key>WatchPaths</key><array><string>$BASE/queue</string></array>
  <key>StandardOutPath</key><string>$BASE/agent.out.log</string>
  <key>StandardErrorPath</key><string>$BASE/agent.err.log</string>
</dict>
</plist>
PLIST

# ---- publish the printer inventory so the mind can always see the options ----
{
  echo "generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "--- lpstat -p -d ---"; lpstat -p -d 2>&1
  echo "--- lpstat -e ---";   lpstat -e 2>&1
  echo "--- queue (lpstat -o) ---"; lpstat -o 2>&1
} > "$BASE/printers.txt" 2>&1

# ---- one-shot maintenance inbox: run any *.cmd dropped in, capture output, archive ----
for c in "$CMD"/*.cmd; do
  [ -e "$c" ] || continue
  cn=$(basename "$c")
  { echo "=== $cn @ $(date '+%Y-%m-%d %H:%M:%S %Z') ==="; /bin/sh "$c" 2>&1; echo "=== exit $? ==="; } > "$CMDDONE/$cn.out" 2>&1
  mv "$c" "$CMDDONE/$cn" 2>/dev/null
done

# ---- print anything queued ----
resolve_target() {
  if [ -f "$BASE/default.printer" ]; then t=$(tr -d '\r\n' < "$BASE/default.printer"); [ -n "$t" ] && { echo "$t"; return; }; fi
  d=$(lpstat -d 2>/dev/null | sed -n 's/^system default destination: //p'); [ -n "$d" ] && { echo "$d"; return; }
  lpstat -e 2>/dev/null | head -n 1
}
for f in "$QUEUE"/*; do
  [ -e "$f" ] || continue
  name=$(basename "$f"); case "$name" in *.printer|.*) continue;; esac
  target=$(resolve_target)
  if [ -f "$QUEUE/$name.printer" ]; then o=$(tr -d '\r\n' < "$QUEUE/$name.printer"); [ -n "$o" ] && target="$o"; fi
  rc="$RECEIPTS/$name.txt"
  {
    echo "=== print receipt ==="; echo "file: $name"; echo "when: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    if [ -n "$target" ]; then echo "target: $target"; echo "lp: $(lp -d "$target" "$f" 2>&1)";
    else echo "target: NONE (no printer found)"; echo "lp: skipped -- no printer available on this Mac"; fi
    echo "--- lpstat -o ---"; lpstat -o 2>&1
  } > "$rc" 2>&1
  mv "$f" "$DONE/$name" 2>/dev/null
  [ -f "$QUEUE/$name.printer" ] && mv "$QUEUE/$name.printer" "$DONE/$name.printer" 2>/dev/null
done
exit 0
