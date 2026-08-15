---
name: install-global-skills
description: >-
  Install this hub's curated global-skills into ~/.cursor/skills (and optionally
  ~/.claude/skills). Use for new machines or missing personal skills.
---

# Install hub global skills

```bash
bash scripts/install-global-skills.sh
```

Default destination: `~/.cursor/skills/`. Never write `~/.cursor/skills-cursor/`.
Populate `global-skills/` + `MANIFEST.json` before relying on this.
