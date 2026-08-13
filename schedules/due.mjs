#!/usr/bin/env node
/**
 * Cheap due-check for hub tick. No network.
 * Usage: node schedules/due.mjs [--json]
 * Prints JSON array of due job objects: [{ id, skill, slack, prompt }, ...]
 * Exit 0 always (empty array = nothing to do).
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REGISTRY = path.join(__dirname, "registry.yaml");
const STATE = path.join(__dirname, "state.json");

function loadState() {
  try {
    return JSON.parse(fs.readFileSync(STATE, "utf8"));
  } catch {
    return {};
  }
}

/** Minimal YAML subset: jobs list with id/enabled/cron/skill/slack/prompt(|). */
function parseRegistry(text) {
  const jobs = [];
  let current = null;
  let inPrompt = false;
  let promptLines = [];

  const flushPrompt = () => {
    if (current && inPrompt) {
      current.prompt = promptLines.join("\n").replace(/\s+$/, "");
      inPrompt = false;
      promptLines = [];
    }
  };

  for (const raw of text.split(/\r?\n/)) {
    if (raw.trimStart().startsWith("#")) continue;
    if (inPrompt) {
      if (/^  - id:/.test(raw) || (/^[a-zA-Z]/.test(raw) && !raw.startsWith(" "))) {
        flushPrompt();
      } else if (raw.startsWith("      ") || raw === "      " || raw.trim() === "") {
        promptLines.push(raw.startsWith("      ") ? raw.slice(6) : "");
        continue;
      } else if (/^    [a-z]+:/.test(raw)) {
        flushPrompt();
      } else {
        promptLines.push(raw.replace(/^      /, ""));
        continue;
      }
    }

    const jobStart = raw.match(/^  - id:\s*(.+)\s*$/);
    if (jobStart) {
      flushPrompt();
      if (current) jobs.push(current);
      current = {
        id: unquote(jobStart[1]),
        enabled: true,
        cron: "* * * * *",
        skill: "",
        slack: "on_fail",
        prompt: "",
      };
      continue;
    }
    if (!current) continue;

    const kv = raw.match(/^    (enabled|cron|skill|slack):\s*(.+)\s*$/);
    if (kv) {
      const key = kv[1];
      let val = unquote(kv[2]);
      if (key === "enabled") val = val === "true";
      current[key] = val;
      continue;
    }
    if (/^    prompt:\s*\|\s*$/.test(raw)) {
      inPrompt = true;
      promptLines = [];
      continue;
    }
    if (/^    prompt:\s*(.+)\s*$/.test(raw)) {
      current.prompt = unquote(raw.match(/^    prompt:\s*(.+)\s*$/)[1]);
    }
  }
  flushPrompt();
  if (current) jobs.push(current);
  return jobs;
}

function unquote(s) {
  s = s.trim();
  if (
    (s.startsWith('"') && s.endsWith('"')) ||
    (s.startsWith("'") && s.endsWith("'"))
  ) {
    return s.slice(1, -1);
  }
  return s;
}

/** Match one cron field against value. Supports *, N, A-B, star/N, A-B/N, lists. */
function fieldMatch(field, value) {
  if (field === "*") return true;
  for (const part of field.split(",")) {
    const stepMatch = part.match(/^(\*|\d+(?:-\d+)?)\/(\d+)$/);
    if (stepMatch) {
      const step = Number(stepMatch[2]);
      if (stepMatch[1] === "*") {
        if (value % step === 0) return true;
        continue;
      }
      const [a, b] = stepMatch[1].includes("-")
        ? stepMatch[1].split("-").map(Number)
        : [Number(stepMatch[1]), Number(stepMatch[1])];
      if (value >= a && value <= b && (value - a) % step === 0) return true;
      continue;
    }
    const range = part.match(/^(\d+)-(\d+)$/);
    if (range) {
      if (value >= Number(range[1]) && value <= Number(range[2])) return true;
      continue;
    }
    if (Number(part) === value) return true;
  }
  return false;
}

function cronMatches(expr, date) {
  const parts = expr.trim().split(/\s+/);
  if (parts.length !== 5) return false;
  const [min, hour, dom, mon, dow] = parts;
  // JS: Sunday=0; cron often Sunday=0 or 7
  let d = date.getDay();
  return (
    fieldMatch(min, date.getMinutes()) &&
    fieldMatch(hour, date.getHours()) &&
    fieldMatch(dom, date.getDate()) &&
    fieldMatch(mon, date.getMonth() + 1) &&
    (fieldMatch(dow, d) || (d === 0 && fieldMatch(dow, 7)))
  );
}

/** Floor to 15-minute bucket start (hub tick cadence). */
function bucketStart(now) {
  const d = new Date(now);
  d.setSeconds(0, 0);
  d.setMinutes(d.getMinutes() - (d.getMinutes() % 15));
  return d;
}

/** First minute in [bucket, bucket+15) where cron matches, or null. */
function fireInBucket(expr, start) {
  for (let m = 0; m < 15; m++) {
    const d = new Date(start);
    d.setMinutes(start.getMinutes() + m);
    if (cronMatches(expr, d)) return d;
  }
  return null;
}

function main() {
  const text = fs.readFileSync(REGISTRY, "utf8");
  const jobs = parseRegistry(text);
  const state = loadState();
  const now = new Date();
  const bucket = bucketStart(now);
  const due = [];

  for (const job of jobs) {
    if (!job.enabled) continue;
    const st = state[job.id] || {};
    if (st.forceDue === true) {
      due.push(job);
      continue;
    }
    const fire = fireInBucket(job.cron, bucket);
    if (!fire) continue;
    const lastRun = st.lastRun ? new Date(st.lastRun) : null;
    if (!lastRun || lastRun < fire) {
      due.push(job);
    }
  }

  const out = due.map((j) => ({
    id: j.id,
    skill: j.skill,
    slack: j.slack,
    prompt: j.prompt || "",
  }));
  process.stdout.write(JSON.stringify(out, null, 2) + "\n");
}

main();
