#!/bin/bash
# health-report.sh — Analyze wiki health: orphans, hubs, broken links, communities.
#
# Uses KiwiFS graph API + tree endpoint for complete file resolution.
# Inspired by SamurAIGPT/llm-wiki-agent's graph health report.
#
# Usage:
#   bash health-report.sh                    Full report (default limit: 15)
#   bash health-report.sh --json            JSON output (all items, no limit)
#   bash health-report.sh --orphans         Only show orphan wiki pages
#   bash health-report.sh --limit 50        Show up to 50 items per category
#   bash health-report.sh --orphans --limit 100  Only orphans, show 100

set -euo pipefail

KIWI_API="${KIWI_API:-http://localhost:3333}"
JSON=false
ORPHANS=false
LIMIT=15

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)    JSON=true; shift ;;
    --orphans) ORPHANS=true; shift ;;
    --limit)   LIMIT="$2"; shift 2 ;;
    *)         echo "Usage: health-report.sh [--json] [--orphans] [--limit N]"; exit 1 ;;
  esac
done

# --- Gather data ---
GRAPH=$(curl -sf "${KIWI_API}/api/kiwi/graph" 2>/dev/null || echo '{"nodes":[],"edges":[]}')

RAW_TREE_FILE=$(mktemp /tmp/kiwi-rawtree-XXXXXX.json)
WIKI_TREE_FILE=$(mktemp /tmp/kiwi-wikitree-XXXXXX.json)
curl -sf "${KIWI_API}/api/kiwi/tree?path=raw/" > "$RAW_TREE_FILE" 2>/dev/null || echo '{}' > "$RAW_TREE_FILE"
curl -sf "${KIWI_API}/api/kiwi/tree?path=wiki/" > "$WIKI_TREE_FILE" 2>/dev/null || echo '{}' > "$WIKI_TREE_FILE"

ANALYTICS_FILE=$(mktemp /tmp/kiwi-health-XXXXXX.json)
curl -sf "${KIWI_API}/api/kiwi/graph/analytics?limit=100" > "$ANALYTICS_FILE" 2>/dev/null || echo '{}' > "$ANALYTICS_FILE"

# --- Run health checks via Python ---
REPORT=$(echo "$GRAPH" | python3 -c '
import sys, json, os

def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except:
        return {}

analytics = load_json(sys.argv[1])
raw_tree = load_json(sys.argv[2])
wiki_tree = load_json(sys.argv[3])

# Read limit from argv[4], default 15
limit = int(sys.argv[4]) if len(sys.argv) > 4 else 15

graph = json.loads(sys.stdin.read())
nodes = graph.get("nodes", [])
edges = graph.get("edges", [])

def norm(path):
    base = os.path.basename(path)
    if base.endswith(".md"):
        base = base[:-3]
    return base

def collect_paths(node, prefix=""):
    paths = []
    for child in node.get("children", []):
        name = child.get("name", "")
        if child.get("isDir", False):
            paths.extend(collect_paths(child, prefix + name + "/"))
        else:
            paths.append((prefix + name, name))
    return paths

raw_files = collect_paths(raw_tree, "raw/")
wiki_files = collect_paths(wiki_tree, "wiki/")
all_files = raw_files + wiki_files

all_basenames = {}
for full_path, name in all_files:
    base = norm(full_path)
    if base not in all_basenames:
        all_basenames[base] = full_path

node_set = {n["path"] for n in nodes}
node_basenames = {}
for p in node_set:
    base = norm(p)
    if base not in node_basenames:
        node_basenames[base] = p

wiki_nodes = [n for n in nodes if n["path"].startswith("wiki/")]
raw_nodes = [n for n in nodes if n["path"].startswith("raw/")]
wiki_basenames = {norm(n["path"]) for n in wiki_nodes}

in_degree = {}
out_degree = {}
for e in edges:
    src = e.get("source", "")
    tgt = e.get("target", "")
    src_full = node_basenames.get(norm(src), src)
    tgt_full = node_basenames.get(norm(tgt), tgt)
    out_degree[src_full] = out_degree.get(src_full, 0) + 1
    in_degree[tgt_full] = in_degree.get(tgt_full, 0) + 1

# 1. Orphan wiki pages
orphan_wiki = []
for p in sorted(wiki_nodes, key=lambda n: n["path"]):
    path = p["path"]
    if not path.endswith(".md"):
        continue
    pg = norm(path)
    if pg in ("index", "log", "overview"):
        continue
    if in_degree.get(path, 0) == 0:
        orphan_wiki.append(path)

# 2. Hub stubs
all_out = list(out_degree.values())
avg_out = sum(all_out) / len(all_out) if all_out else 0
hub_stubs = []
for p in wiki_nodes:
    path = p["path"]
    od = out_degree.get(path, 0)
    if od > avg_out * 2 and od >= 3:
        hub_stubs.append({"path": path, "out_degree": od})
hub_stubs.sort(key=lambda x: -x["out_degree"])

# 3. Broken wikilinks
broken = []
for e in edges:
    tgt = e.get("target", "")
    if tgt.startswith("raw/") or tgt.startswith("/"):
        continue
    tgt_base = norm(tgt)
    in_graph = tgt_base in node_basenames or tgt in node_set
    in_tree = tgt_base in all_basenames or tgt in all_basenames
    raw_path = "raw/" + tgt
    raw_base = norm(raw_path)
    in_tree_raw = raw_base in all_basenames or raw_path in all_basenames
    if not in_graph and not in_tree and not in_tree_raw:
        broken.append(tgt)

broken_targets = sorted(set(broken))

# 4. Edge-to-node ratio
wiki_edge_count = 0
for e in edges:
    src_base = norm(e.get("source", ""))
    if src_base in wiki_basenames:
        wiki_edge_count += 1
edge_to_node = round(wiki_edge_count / len(wiki_nodes), 2) if wiki_nodes else 0

total_graph_nodes = analytics.get("total_nodes", len(nodes))
total_graph_edges = analytics.get("total_edges", len(edges))
components = analytics.get("components", 0)

result = {
    "total_graph_nodes": total_graph_nodes,
    "total_graph_edges": total_graph_edges,
    "wiki_pages": len(wiki_nodes),
    "raw_files": len(raw_nodes),
    "wiki_orphans": len(orphan_wiki),
    "orphan_list": orphan_wiki[:limit],
    "hub_stubs": hub_stubs[:max(5, limit//2)],
    "broken_links": len(broken_targets),
    "broken_list": broken_targets[:limit],
    "components": components,
    "edge_to_node_ratio": edge_to_node,
    "avg_out_degree": round(avg_out, 2)
}

print(json.dumps(result, indent=2))
' "$ANALYTICS_FILE" "$RAW_TREE_FILE" "$WIKI_TREE_FILE" "$LIMIT")

rm -f "$ANALYTICS_FILE" "$RAW_TREE_FILE" "$WIKI_TREE_FILE"

if $JSON; then
  echo "$REPORT"
  exit 0
fi

# --- Format as human-readable report ---
echo "$REPORT" > /tmp/kiwi-format-report.json

# Pass ORPHANS mode via env var so the heredoc can read it
export ORPHANS_MODE=$($ORPHANS && echo "true" || echo "false")
export DISPLAY_LIMIT=$LIMIT

python3 << 'PYEOF'
import json, os, sys

with open("/tmp/kiwi-format-report.json") as f:
    r = json.load(f)

orphans_only = os.environ.get("ORPHANS_MODE", "false") == "true"
limit = int(os.environ.get("DISPLAY_LIMIT", "15"))

def g(key):
    return r.get(key, 0)

def name(path):
    return path.replace("wiki/", "", 1).replace(".md", "", 1)

orphans = r.get("orphan_list", [])
stubs = r.get("hub_stubs", [])
broken = r.get("broken_list", [])
comps = g("components")

if not orphans_only:
    print("─────────────────────────────────────────────")
    print("  Wiki Health Report")
    print("─────────────────────────────────────────────")
    print("  Graph nodes:       {}".format(g("total_graph_nodes")))
    print("  Graph edges:       {}".format(g("total_graph_edges")))
    print("  Wiki pages:        {}".format(g("wiki_pages")))
    print("  Raw files:         {}".format(g("raw_files")))
    print("  Orphan wiki pages: {}".format(g("wiki_orphans")))
    print("  Broken links:      {}".format(g("broken_links")))
    print("  Communities:       {}".format(g("components")))
    print("  Edge-to-node:      {}".format(g("edge_to_node_ratio")))
    print("  Avg out-degree:    {}".format(g("avg_out_degree")))
    print("─────────────────────────────────────────────")

if orphans:
    print("")
    print("⚠  {} orphan wiki pages (no inbound [[links]]):".format(g("wiki_orphans")))
    shown = 0
    total_orphans = g("wiki_orphans")
    for p in orphans:
        shown += 1
        if shown > limit:
            remaining = total_orphans - limit
            if remaining > 0:
                print("   ... and {} more".format(remaining))
            break
        print("   - [[{}]]".format(name(p)))
    print("   💡 Add [[links]] from related pages to connect orphans.")

if orphans_only:
    if not orphans:
        print("✓ No orphan pages found.")
    sys.exit(0)

if stubs:
    print("")
    print("⚡  {} potential hub stubs:".format(len(stubs)))
    for h in stubs[:5]:
        print("   - [[{}]] ({} outbound links)".format(name(h.get("path","")), h.get("out_degree",0)))
    if len(stubs) > 5:
        print("   ... and {} more".format(len(stubs) - 5))
    print("   💡 Read these pages. High link count with shallow content")
    print("      suggests the page is well-connected but lacks depth.")

if broken:
    print("")
    print("💔  {} broken [[wikilinks]]:".format(g("broken_links")))
    shown = 0
    total_broken = g("broken_links")
    for b in broken:
        shown += 1
        if shown > limit:
            remaining = total_broken - limit
            if remaining > 0:
                print("   ... and {} more".format(remaining))
            break
        print("   - [[{}]]".format(b))
    print("   💡 Either create the missing pages or remove the links.")

if comps > 1:
    print("")
    print("🌐  {} knowledge communities detected.".format(comps))
    print("   💡 Isolated clusters mean knowledge fragmentation.")
    print("      An edge-to-node ratio < 8 suggests sparse linking.")

if not orphans and not broken:
    print("")
    print("✓ No issues detected -- wiki is healthy.")
PYEOF
rm -f /tmp/kiwi-format-report.json
