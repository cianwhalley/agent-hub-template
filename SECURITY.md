# Security policy

Use [GitHub Private Vulnerability Reporting](https://github.com/zenmindhacker/agent-hub-template/security/advisories/new).

Do not file a public issue for token leaks, git-askpass bugs, or Slack posting that dumps secrets.

In scope: scripts that handle `HUB_GITHUB_TOKEN_FILE`, Slack bot tokens in `slack-post.sh`, and any path that could commit `.env` / `*.token`.
