#!/usr/bin/env node
/**
 * Prepare isolated due-job runs with primary + fallback models for run-tick.sh.
 * Usage: node schedules/group-due-models.mjs <<EOF
 *   [ { id, model, ... }, ... ]
 * EOF
 * Env:
 *   AGENT_MODEL = default when job.model is empty
 *   AGENT_MODEL_FALLBACK = default when job.fallbackModel is empty
 * Prints one NDJSON line per job so a failed model cannot strand unrelated work.
 * Strips a trailing -fast so scheduled work stays non-fast ("slow").
 */
import fs from "node:fs";

const DEFAULT = (process.env.AGENT_MODEL || "cursor-grok-4.6-medium").trim();
const DEFAULT_FALLBACK = (
  process.env.AGENT_MODEL_FALLBACK || "gpt-5.6-sol-medium"
).trim();

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

for (const job of due) {
  const model = preferSlow(job.model);
  const configuredFallback = (job.fallbackModel || DEFAULT_FALLBACK).trim();
  const fallbackModel = /^(off|none)$/i.test(configuredFallback)
    ? ""
    : preferSlow(configuredFallback);
  process.stdout.write(
    JSON.stringify({ model, fallbackModel, jobs: [job] }) + "\n",
  );
}
