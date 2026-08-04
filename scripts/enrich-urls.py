#!/usr/bin/env python3
"""Enrich bare URLs in raw notes with title + description.

For each URL found in raw/**/*.md that doesn't already have context,
fetch the page title and meta description, then add a context line
before the URL in the note.

Usage: python3 enrich-urls.py [--dry-run] [--batch-size 50] [--pause 1]
"""
import os, re, sys, time, urllib.request, urllib.error
from html.parser import HTMLParser
from pathlib import Path

KB_DIR = os.environ.get("KB_DIR", os.path.expanduser("~/octarine-notes"))
RAW_DIR = Path(KB_DIR) / "raw"
BATCH_SIZE = int(os.environ.get("BATCH_SIZE", "50"))
PAUSE = float(os.environ.get("PAUSE", "1"))
DRY_RUN = "--dry-run" in sys.argv

class TitleDescParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.title = ""
        self.desc = ""
        self.in_title = False
        self.title_done = False
    def handle_starttag(self, tag, attrs):
        if tag == "title":
            self.in_title = True
        if tag == "meta":
            d = dict(attrs)
            if d.get("name","").lower() in ("description", "og:description"):
                self.desc = d.get("content","")[:200]
    def handle_data(self, data):
        if self.in_title:
            self.title += data
    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False

def fetch_title_desc(url, timeout=5):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if "text/html" not in resp.headers.get("Content-Type",""):
                return None, None
            html = resp.read(50000).decode("utf-8", errors="ignore")
            p = TitleDescParser()
            p.feed(html)
            return p.title.strip()[:150], p.desc.strip()[:200]
    except Exception:
        return None, None

def url_repl(match):
    """Check if URL already has context (is part of [text](url) or has nearby title)."""
    return match.group(0)

def process_file(filepath, dry_run=False):
    """Process one file: find bare URLs, fetch context, enrich."""
    content = filepath.read_text(encoding="utf-8", errors="ignore")
    lines = content.split("\n")
    modified = False
    enriched = 0

    # Find URLs in body (skip frontmatter)
    in_frontmatter = False
    for i, line in enumerate(lines):
        if line.strip() == "---":
            in_frontmatter = not in_frontmatter
            continue
        if in_frontmatter:
            continue

        # Find bare URLs (not already in [text](url) format)
        urls = re.findall(r'(?<!\()(https?://[^\s\)\]>"]+)', line)
        for url in urls:
            # Skip if URL already has context nearby (same line has text before it)
            before_url = line[:line.index(url)].strip()
            if before_url and not before_url.startswith("url:"):
                continue  # Already has context

            # Skip if context line already exists (check line above)
            if i > 0 and re.match(r'^\[.*\]\(', lines[i-1].strip()):
                continue

            title, desc = fetch_title_desc(url)
            if not title and not desc:
                continue

            # Build context line
            context_parts = []
            if title:
                context_parts.append(f'"{title}"')
            if desc:
                context_parts.append(desc[:100])
            context = " — ".join(context_parts)

            if not context:
                continue

            # Insert context line before the URL
            indent = re.match(r'^(\s*)', line).group(1)
            context_line = f'{indent}({context})'
            lines.insert(i, context_line)
            modified = True
            enriched += 1
            break  # One URL per line is enough

    if modified and not dry_run:
        filepath.write_text("\n".join(lines), encoding="utf-8")

    return enriched

def main():
    print(f"[enrich] KB_DIR: {KB_DIR}")
    print(f"[enrich] batch size: {BATCH_SIZE}, pause: {PAUSE}s, dry_run: {DRY_RUN}")

    # Find all .md files with URLs
    files_with_urls = []
    for f in RAW_DIR.rglob("*.md"):
        content = f.read_text(encoding="utf-8", errors="ignore")
        if re.search(r'https?://', content):
            files_with_urls.append(f)

    print(f"[enrich] files with URLs: {len(files_with_urls)}")

    total_enriched = 0
    processed = 0

    for i, f in enumerate(files_with_urls):
        enriched = process_file(f, DRY_RUN)
        total_enriched += enriched
        processed += 1

        if processed % BATCH_SIZE == 0:
            print(f"[enrich] processed {processed}/{len(files_with_urls)}, enriched {total_enriched} URLs")
            if not DRY_RUN:
                time.sleep(PAUSE)

    print(f"[enrich] done: processed {processed} files, enriched {total_enriched} URLs")

if __name__ == "__main__":
    main()
