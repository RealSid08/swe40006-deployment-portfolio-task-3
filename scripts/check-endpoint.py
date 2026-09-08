"""Verify real HTTP responses and backend distribution, without modifying the site."""

import argparse
import json
from collections import Counter
from urllib.request import urlopen


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("--requests", type=int, default=20)
    parser.add_argument("--minimum-nodes", type=int, default=1)
    args = parser.parse_args()
    nodes = Counter()
    for _ in range(args.requests):
        with urlopen(args.url.rstrip("/") + "/health.php", timeout=10) as response:
            assert response.status == 200
            result = json.load(response)
        assert result["status"] == "healthy", result
        assert result["published_posts"] == 3, result
        nodes[result["node"]] += 1
    assert len(nodes) >= args.minimum_nodes, f"Only saw these backend nodes: {nodes}"
    print(json.dumps({"url": args.url, "successful_requests": args.requests,
                      "database": result["database"], "published_posts": 3,
                      "backend_responses": dict(nodes)}, indent=2))


if __name__ == "__main__":
    main()
