#!/usr/bin/env node
/**
 * Group due-job JSON (stdin) by model for run-tick.sh.
 * Usage: node schedules/group-due-models.mjs <<EOF
 *   [ { id, model, ... }, ... ]
 * EOF
 * Env: AGENT_MODEL = default when job.model empty (fallback cursor-grok-4.6-medium)
 * Prints NDJSON lines: { "model": "...", "jobs": [ ... ] }
 * Strips a trailing -fast so scheduled work stays non-fast ("slow").
 */
import fs from "node:fs";

const DEFAULT = (process.env.AGENT_MODEL || "cursor-grok-4.6-medium").trim();

function preferSlow(model) {
  const m = (model || DEFAULT).trim() || DEFAULT;
  return m.endsWith("-fast") ? m.slice(0, -"-fast".length) : m;
}

const raw = fs.readFileSync(0, "utf8");
const due = JSON.parse(raw);
if (!Array.isArray(due)) {
  console.error("group-due-models: expected JSON array on stdin");
  process.exit(1);
}

const groups = new Map();
for (const job of due) {
  const model = preferSlow(job.model);
  if (!groups.has(model)) groups.set(model, []);
  groups.get(model).push(job);
}

for (const [model, jobs] of groups) {
  process.stdout.write(JSON.stringify({ model, jobs }) + "\n");
}
