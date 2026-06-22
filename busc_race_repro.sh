#!/bin/bash
# ---------------------------------------------------------------------------
# Reproduces the OpacBrowseResults "busc" lost-update race.
#
# Each trial seeds a fresh anonymous session, then fires the search request
# (which stores `busc`) CONCURRENTLY with several other same-session requests
# (mimicking the parallel requests a real browser makes: covers, AJAX, etc.).
# It then loads the detail page and checks whether the Browse-results pane
# rendered.
#
#   PANE   = browse pane present  (busc survived)
#   absent = browse pane missing  (busc was clobbered = the bug)
#
# Run inside the KTD container:
#   bash /kohadevbox/koha/busc_race_repro.sh [TRIALS] [CONCURRENT_NOISE]
# e.g.
#   bash /kohadevbox/koha/busc_race_repro.sh 100 8
#
# Prereqs:
#   - OpacBrowseResults syspref enabled
#   - the OPAC has searchable records (the search below uses q=a)
# ---------------------------------------------------------------------------

BASE="http://localhost:8080/cgi-bin/koha"
ITER="${1:-100}"     # number of trials
NOISE="${2:-8}"      # concurrent same-session requests racing the search
QUERY="${3:-a}"      # search term (must return results)

PROGRESS="/tmp/busc_progress"   # one char appended per completed trial

trial() {
  i="$1"
  jar="/tmp/busc_jar.$i"
  body="/tmp/busc_body.$i"

  # 1) seed an anonymous session (gets a CGISESSID)
  curl -s -c "$jar" -b "$jar" "$BASE/opac-main.pl" -o /dev/null

  # 2) fire the search (stores busc) at the SAME TIME as noise requests that
  #    each load + rewrite the shared session blob -> the race
  curl -s -c "$jar" -b "$jar" "$BASE/opac-search.pl?q=$QUERY" -o "$body" &
  for k in $(seq 1 "$NOISE"); do
    curl -s -c "$jar" -b "$jar" "$BASE/opac-main.pl" -o /dev/null &
  done
  wait

  # 3) open the first result's detail page and check whether busc survived.
  #    Detection must handle two markup eras:
  #    - Pre-Bug-41582: the browse pane is gated server-side by [% IF busc %], so
  #      the `results-pagination` markup is present only when busc exists.
  #    - Bug-41582+ (e.g. main): the markup is always emitted and gated in JS via
  #      `const busc = "..."`, so an EMPTY `const busc = ""` is the clobber signal.
  #      (Grepping `results-pagination` here gives FALSE positives.)
  bib=$(grep -oE 'opac-detail.pl\?biblionumber=[0-9]+' "$body" | head -1 | grep -oE '[0-9]+')
  local result det="/tmp/busc_detail.$i"
  if [ -n "$bib" ]; then
    curl -s -c "$jar" -b "$jar" "$BASE/opac-detail.pl?biblionumber=$bib" -o "$det"
    if grep -q 'const busc' "$det"; then
      # Bug-41582+ markup: pane gated client-side via const busc
      if grep -qF 'const busc = ""' "$det"; then result=absent; else result=PANE; fi
    else
      # legacy markup: pane gated server-side by [% IF busc %]
      if grep -q 'results-pagination' "$det"; then result=PANE; else result=absent; fi
    fi
    rm -f "$det"
  else
    result=NOBIB
  fi
  rm -f "$jar" "$body"

  # --- live progress (to stderr so it doesn't pollute the captured tally) ---
  # append a marker and report running totals
  case "$result" in
    PANE)   printf '.' >>"$PROGRESS" ;;   # . = busc survived
    absent) printf 'X' >>"$PROGRESS" ;;   # X = busc clobbered (the bug)
    *)      printf '?' >>"$PROGRESS" ;;
  esac
  local done ok bad
  done=$(wc -c <"$PROGRESS" | tr -d ' ')
  ok=$(tr -cd '.' <"$PROGRESS" | wc -c | tr -d ' ')
  bad=$(tr -cd 'X' <"$PROGRESS" | wc -c | tr -d ' ')
  printf 'trial %3d/%d  ->  %-6s   (running: %d PANE / %d absent)\n' \
    "$done" "$ITER" "$result" "$ok" "$bad" >&2

  echo "$result"
}
export -f trial
export BASE NOISE QUERY ITER PROGRESS

: >"$PROGRESS"   # reset progress marker file
echo "Running $ITER trials, $NOISE concurrent noise requests each, query='$QUERY'..." >&2
echo "(each line below = one completed trial; X = the bug reproduced)" >&2
echo >&2

# trial's stdout (PANE/absent) -> results file; its stderr (progress) -> terminal
seq 1 "$ITER" | xargs -P 10 -I{} bash -c 'trial "$@"' _ {} > /tmp/busc_results.txt

echo >&2
echo "==================== RESULTS ===================="
echo "trials: $ITER   concurrent noise/req: $NOISE   query: '$QUERY'"
echo "PANE   (busc survived): $(grep -c PANE   /tmp/busc_results.txt)"
echo "absent (busc clobbered): $(grep -c absent /tmp/busc_results.txt)"
echo "NOBIB  (search returned nothing): $(grep -c NOBIB /tmp/busc_results.txt)"
rm -f "$PROGRESS"
