#!/usr/bin/env node
/**
 * Mark a job forceDue for the next hub tick (or clear).
 * Usage: node schedules/force.mjs <id> [on|off]
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const STATE = path.join(__dirname, "state.json");

const [id, mode = "on"] = process.argv.slice(2);
if (!id) {
  console.error("usage: node schedules/force.mjs <id> [on|off]");
  process.exit(2);
}

let state = {};
try {
  state = JSON.parse(fs.readFileSync(STATE, "utf8"));
} catch {
  /* empty */
}

const entry = state[id] || {};
if (mode === "off") {
  delete entry.forceDue;
} else {
  entry.forceDue = true;
}
state[id] = entry;
fs.writeFileSync(STATE, JSON.stringify(state, null, 2) + "\n", "utf8");
console.log(`${id}: forceDue=${entry.forceDue === true}`);
