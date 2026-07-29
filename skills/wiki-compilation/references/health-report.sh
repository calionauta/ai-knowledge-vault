#!/bin/bash
# health-report.sh — Analyze wiki health: orphans, hubs, broken links, communities.
#
# Uses KiwiFS graph API (nodes, edges, analytics).
# Inspired by SamurAIGPT/llm-wiki-agent's graph health report.
#
# Usage: bash health-report.sh [--json]

set -euo pipefail

KIWI_API="${KIWI_API:-http://localhost:3333}"
JSON=false
[[ "${1:-}" == "--json" ]] && JSON=true

# --- Gather data ---
GRAPH=$(curl -sf "${KIWI_API}/api/kiwi/graph" 2>/dev/null || echo '{"nodes":[],"edges":[]}')

# Analytics is large, pass via temp file
ANALYTICS_FILE=$(mktemp /tmp/kiwi-health-XXXXXX.json)
curl -sf "${KIWI_API}/api/kiwi/graph/analytics?limit=100" > "$ANALYTICS_FILE" 2>/dev/null || echo '{}' > "$ANALYTICS_FILE"

# --- Run health checks via Python ---
REPORT=$(echo "$GRAPH" | python3 -c '
import sys, json, os

# Read analytics from file passed as argument
analytics_file = sys.argv[1] if len(sys.argv) > 1 else "/dev/null"
try:
    with open(analytics_file) as f:
        analytics = json.load(f)
except:
    analytics = {}

graph = json.loads(sys.stdin.read())
nodes = graph.get("nodes", [])
edges = graph.get("edges", [])

# Build maps
node_set = {n["path"] for n in nodes}

# Normalized node names: strip directory prefix and .md extension
# e.g. "wiki/concepts/Reautoria.md" → "Reautoria"
normalized_names = set()
for p in node_set:
    if p.endswith(".md"):
        base = os.path.basename(p)
        base = base[:-3]  # strip .md
        normalized_names.add(base)

in_degree = {}
out_degree = {}
for e in edges:
    src = e.get("source", "")
    tgt = e.get("target", "")
    out_degree[src] = out_degree.get(src, 0) + 1
    in_degree[tgt] = in_degree.get(tgt, 0) + 1

# Separate wiki from raw
wiki_nodes = [n for n in nodes if n["path"].startswith("wiki/")]
raw_nodes = [n for n in nodes if n["path"].startswith("raw/")]
wiki_paths = {n["path"] for n in wiki_nodes}

# 1. Orphan wiki pages (zero inbound links)
orphan_wiki = []
for p in wiki_paths:
    if not p.endswith(".md"):
        continue
    pg = p.replace("wiki/", "", 1).replace(".md", "", 1)
    if pg in ("index", "log", "overview"):
        continue
    if in_degree.get(p, 0) == 0:
        orphan_wiki.append(p)

# 2. Hub stubs: pages with out_degree > avg*2
all_out = list(out_degree.values())
avg_out = sum(all_out) / len(all_out) if all_out else 0
hub_stubs = []
for p in wiki_paths:
    od = out_degree.get(p, 0)
    if od > avg_out * 2 and od >= 3:
        hub_stubs.append({"path": p, "out_degree": od})
hub_stubs.sort(key=lambda x: -x["out_degree"])

# 3. Broken wikilinks: edges targeting non-existent pages
# Nodes have paths like "wiki/concepts/Reautoria.md" but wikilinks in edges
# are just "Reautoria" (no prefix, no extension). Normalize both for comparison.
broken = []
for e in edges:
    tgt = e.get("target", "")
    # Skip raw/ and absolute paths (they exist by definition)
    if tgt.startswith("raw/") or tgt.startswith("/"):
        continue
    # Check against full paths, normalized names, and wiki/ prefix
    if tgt not in node_set and tgt not in normalized_names and "wiki/" + tgt not in node_set:
        broken.append(tgt)

broken_targets = sorted(set(broken))

# 4. Community / component info from analytics
total_graph_nodes = analytics.get("total_nodes", len(nodes))
total_graph_edges = analytics.get("total_edges", len(edges))
components = analytics.get("components", 0)
analytics_orphans = analytics.get("orphans", [])

# Edge-to-node ratio (wiki pages only)
wiki_edge_count = sum(1 for e in edges if e.get("source","").startswith("wiki/"))
edge_to_node = round(wiki_edge_count / len(wiki_nodes), 2) if wiki_nodes else 0

result = {
    "total_graph_nodes": total_graph_nodes,
    "total_graph_edges": total_graph_edges,
    "wiki_pages": len(wiki_nodes),
    "raw_files": len(raw_nodes),
    "wiki_orphans": len(orphan_wiki),
    "orphan_list": orphan_wiki[:15],
    "hub_stubs": hub_stubs[:10],
    "broken_links": len(broken_targets),
    "broken_list": broken_targets[:15],
    "components": components,
    "edge_to_node_ratio": edge_to_node,
    "avg_out_degree": round(avg_out, 2)
}

print(json.dumps(result, indent=2))
' "$ANALYTICS_FILE")

# Cleanup
rm -f "$ANALYTICS_FILE"

if $JSON; then
  echo "$REPORT"
  exit 0
fi

# --- Format as human-readable report ---
echo "$REPORT" > /tmp/kiwi-format-report.json
python3 << 'PYEOF'
import json

with open("/tmp/kiwi-format-report.json") as f:
    r = json.load(f)

def g(key):
    return r.get(key, 0)

def name(path):
    return path.replace("wiki/", "", 1).replace(".md", "", 1)

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

orphans = r.get("orphan_list", [])
if orphans:
    print("")
    print("⚠  Orphan wiki pages (no inbound links):")
    for p in orphans[:10]:
        print("   - [[{}]]".format(name(p)))
    if len(orphans) > 10:
        print("   ... and {} more".format(len(orphans) - 10))

stubs = r.get("hub_stubs", [])
if stubs:
    print("")
    print("⚡ Potential hub stubs (many links, check content depth):")
    for h in stubs[:5]:
        print("   - [[{}]] ({} outbound links)".format(name(h.get("path","")), h.get("out_degree",0)))

broken = r.get("broken_list", [])
if broken:
    print("")
    print("💔 Broken wikilinks (target page does not exist):")
    for b in broken[:10]:
        print("   - [[{}]]".format(b))
    if len(broken) > 10:
        print("   ... and {} more".format(len(broken) - 10))

comps = g("components")
if comps > 1:
    print("")
    print("🌐 {} knowledge communities detected.".format(comps))
    print("   More than 1 community may indicate isolated topic clusters.")

if not orphans and not broken:
    print("")
    print("✓ No issues detected -- wiki is healthy.")
PYEOF
rm -f /tmp/kiwi-format-report.json
