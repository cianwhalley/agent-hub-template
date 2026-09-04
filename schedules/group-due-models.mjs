#!/usr/bin/env node
/**
 * Prepare isolated due-job runs with primary + fallback specs for run-tick.sh.
 * Usage: node schedules/group-due-models.mjs <<EOF
 *   [ { id, model, ... }, ... ]
 * EOF
 * Env:
 *   AGENT_MODEL = default when job.model is empty
 *   AGENT_MODEL_FALLBACK = comma hops (latest,sonnet,sol) when job.fallbackModel is empty
 * Prints one NDJSON line per job so a failed model cannot strand unrelated work.
 * Strips a trailing -fast on the primary so scheduled work stays non-fast ("slow").
 */
import fs from "node:fs";
import { parseSpecs, preferSlow } from "./model-chain.mjs";

const DEFAULT = (process.env.AGENT_MODEL || "cursor-grok-4.6-medium").trim();
const DEFAULT_FALLBACK = (
  process.env.AGENT_MODEL_FALLBACK || "latest,sonnet,sol"
).trim();

const raw = fs.readFileSync(0, "utf8");
const due = JSON.parse(raw);
if (!Array.isArray(due)) {
  console.error("group-due-models: expected JSON array on stdin");
  process.exit(1);
}

for (const job of due) {
  const model = preferSlow(job.model || DEFAULT) || DEFAULT;
  const configured = (job.fallbackModel || DEFAULT_FALLBACK).trim();
  const fallbackSpecs = parseSpecs(configured).map((s) =>
    /^(latest|sonnet|sonnet-5|sol|gpt-sol|auto)$/i.test(s) ? s : preferSlow(s),
  );
  process.stdout.write(
    JSON.stringify({
      model,
      fallbackSpecs,
      fallbackModel: fallbackSpecs.join(",") || "off",
      jobs: [job],
    }) + "\n",
  );
}
