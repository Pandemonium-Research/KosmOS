#!/usr/bin/env python3
"""
KosmOS end-to-end agent test.

3-step agentic workflow:
  1. Search — query SearXNG for recent AI news
  2. Store — embed and store the results in ChromaDB
  3. Retrieve + summarize — query the collection and generate a grounded summary

All tools are local: no cloud API key required.

Usage:
  python tests/agent_e2e.py
  python tests/agent_e2e.py --model llama3.2:3b
  python tests/agent_e2e.py --query "recent LLM breakthroughs"
"""

import argparse
import json
import sys
import time
import urllib.parse
import urllib.request
from typing import Any

# ── Config ─────────────────────────────────────────────────────────────────────

LITELLM_BASE = "http://127.0.0.1:4000/v1"
LITELLM_KEY  = "kosmos-local"
SEARXNG_BASE = "http://127.0.0.1:8888"
CHROMA_BASE  = "http://127.0.0.1:8000"
COLLECTION   = "kosmos"


# ── Helpers ────────────────────────────────────────────────────────────────────

def http_get(url: str) -> Any:
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read())


def http_post(url: str, body: Any, headers: dict | None = None) -> Any:
    data = json.dumps(body).encode()
    h = {"Content-Type": "application/json", **(headers or {})}
    req = urllib.request.Request(url, data=data, headers=h, method="POST")
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def log(step: int, msg: str) -> None:
    print(f"\n[step {step}] {msg}")


def ok(msg: str) -> None:
    print(f"  ✓ {msg}")


def fail(msg: str) -> None:
    print(f"  ✗ {msg}", file=sys.stderr)
    sys.exit(1)


# ── Step 1: Search ─────────────────────────────────────────────────────────────

def search(query: str) -> list[dict]:
    log(1, f"Searching SearXNG: '{query}'")
    params = urllib.parse.urlencode({"q": query, "format": "json", "categories": "general", "engines": "google,duckduckgo"})
    url = f"{SEARXNG_BASE}/search?{params}"
    try:
        results = http_get(url)
    except Exception as e:
        fail(f"SearXNG search failed: {e}")

    hits = results.get("results", [])[:5]
    if not hits:
        fail("SearXNG returned 0 results — is the service running?")

    ok(f"Got {len(hits)} results")
    for i, r in enumerate(hits, 1):
        print(f"    {i}. {r.get('title', 'no title')} — {r.get('url', '')[:80]}")

    return [{"title": r.get("title", ""), "url": r.get("url", ""), "content": r.get("content", "")} for r in hits]


# ── Step 2: Store in ChromaDB ──────────────────────────────────────────────────

def store(results: list[dict], query: str) -> None:
    log(2, f"Storing {len(results)} results in ChromaDB collection '{COLLECTION}'")

    # Ensure collection exists
    try:
        http_post(f"{CHROMA_BASE}/api/v1/collections", {"name": COLLECTION})
    except Exception:
        pass  # 409 already exists

    # Get collection id
    try:
        cols = http_get(f"{CHROMA_BASE}/api/v1/collections/{COLLECTION}")
        col_id = cols["id"]
    except Exception as e:
        fail(f"Could not get ChromaDB collection: {e}")

    docs    = [f"{r['title']}\n{r['content']}" for r in results]
    ids     = [f"search_{i}_{int(time.time())}" for i in range(len(results))]
    metas   = [{"url": r["url"], "query": query, "ts": int(time.time())} for r in results]

    try:
        http_post(
            f"{CHROMA_BASE}/api/v1/collections/{col_id}/add",
            {"ids": ids, "documents": docs, "metadatas": metas},
        )
        ok(f"Stored {len(docs)} documents (ids: {ids[0]} … {ids[-1]})")
    except Exception as e:
        fail(f"ChromaDB add failed: {e}")


# ── Step 3: Retrieve + summarize ───────────────────────────────────────────────

def summarize(query: str, model: str) -> str:
    log(3, f"Querying ChromaDB and summarizing with '{model}'")

    # Retrieve
    try:
        cols = http_get(f"{CHROMA_BASE}/api/v1/collections/{COLLECTION}")
        col_id = cols["id"]
        qr = http_post(
            f"{CHROMA_BASE}/api/v1/collections/{col_id}/query",
            {"query_texts": [query], "n_results": 5, "include": ["documents", "metadatas"]},
        )
        docs = qr["documents"][0]
        metas = qr["metadatas"][0]
        ok(f"Retrieved {len(docs)} relevant chunks from ChromaDB")
    except Exception as e:
        fail(f"ChromaDB query failed: {e}")

    # Build context
    context_parts = []
    for doc, meta in zip(docs, metas):
        url = meta.get("url", "")
        context_parts.append(f"Source: {url}\n{doc}")
    context = "\n\n---\n\n".join(context_parts)

    # Summarize
    prompt = (
        f"You are a research assistant. Using ONLY the sources below, "
        f"write a concise 3-sentence summary answering the query: '{query}'\n\n"
        f"Sources:\n{context}"
    )

    try:
        resp = http_post(
            f"{LITELLM_BASE}/chat/completions",
            {
                "model": model,
                "messages": [{"role": "user", "content": prompt}],
                "max_tokens": 256,
                "temperature": 0.2,
            },
            headers={"Authorization": f"Bearer {LITELLM_KEY}"},
        )
        summary = resp["choices"][0]["message"]["content"].strip()
        ok(f"Summary generated ({len(summary)} chars)")
        return summary
    except Exception as e:
        fail(f"LLM summarization failed: {e}")


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="KosmOS 3-step agent e2e test")
    parser.add_argument("--query", default="recent advances in large language models 2025")
    parser.add_argument("--model", default="qwen2.5:7b")
    args = parser.parse_args()

    print("━" * 56)
    print("  KosmOS Agent E2E Test")
    print(f"  query: {args.query}")
    print(f"  model: {args.model}")
    print("━" * 56)

    t0 = time.time()

    results = search(args.query)
    store(results, args.query)
    summary = summarize(args.query, args.model)

    elapsed = time.time() - t0

    print("\n" + "━" * 56)
    print("  SUMMARY")
    print("━" * 56)
    print(summary)
    print("━" * 56)
    print(f"\n✓ Test passed in {elapsed:.1f}s\n")


if __name__ == "__main__":
    main()
