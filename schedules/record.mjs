#!/usr/bin/env node
/**
 * Update schedules/state.json after a job run (local only, gitignored).
 * Usage:
 *   node schedules/record.mjs <id> ok
 *   node schedules/record.mjs <id> fail "short error"
 *   node schedules/record.mjs <id> clear-force
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const STATE = path.join(__dirname, "state.json");
const LOG = path.join(__dirname, "runs.log");

function loadState() {
  try {
    return JSON.parse(fs.readFileSync(STATE, "utf8"));
  } catch {
    return {};
  }
}

function saveState(state) {
  fs.writeFileSync(STATE, JSON.stringify(state, null, 2) + "\n", "utf8");
}

const [id, status, ...rest] = process.argv.slice(2);
if (!id || !status) {
  console.error(
    "usage: node schedules/record.mjs <id> ok|fail|clear-force [error]",
  );
  process.exit(2);
}

const state = loadState();
const now = new Date().toISOString();
const entry = state[id] || {};

if (status === "clear-force") {
  delete entry.forceDue;
  state[id] = entry;
  saveState(state);
  console.log(`cleared forceDue for ${id}`);
  process.exit(0);
}

if (status !== "ok" && status !== "fail") {
  console.error("status must be ok|fail|clear-force");
  process.exit(2);
}

entry.lastRun = now;
entry.lastStatus = status;
entry.lastError = status === "fail" ? rest.join(" ").slice(0, 500) : "";
delete entry.forceDue;
state[id] = entry;
saveState(state);

const line = `${now}\t${id}\t${status}\t${entry.lastError || ""}\n`;
fs.appendFileSync(LOG, line, "utf8");
console.log(`recorded ${id} ${status}`);
