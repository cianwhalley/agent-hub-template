#!/usr/bin/env node
/**
 * Resolve Cursor model fallback hops for silas-tick.
 *
 *   node schedules/model-chain.mjs --primary ID --error-file PATH --specs latest,sonnet,sol [--slow]
 *
 * Prints remaining model ids, one per line. Empty stdout = no retry.
 *
 * Specs:
 *   latest — newer same-family same-options (from "Available models:"), else auto
 *   sonnet — latest claude-sonnet-5 matching options
 *   sol    — latest gpt-*-sol matching options
 *   or a concrete Cursor model id
 */
import fs from "node:fs";
import { pathToFileURL } from "node:url";

export const AUTO_MODEL = "auto";
export const DEFAULT_SPECS = ["latest", "sonnet", "sol"];

const EFFORTS = [
  "extra-high",
  "xhigh",
  "max",
  "high",
  "medium",
  "low",
  "minimal",
  "none",
];

export const MODEL_FAILURE_RE =
  "resource_exhausted|retriableerror|connection lost|out of usage|actionrequirederror|service unavailable|temporarily unavailable|model.*unavailable|provider.*degraded|overloaded|at capacity|upstream error|bad gateway|gateway timeout|cannot use this model|available models:|unknown model|invalid model|model not found|unsupported model";

export function isRetryableModelError(text) {
  const t = (text || "").toLowerCase();
  if (!t.trim()) return false;
  return new RegExp(MODEL_FAILURE_RE, "i").test(t);
}

export function parseAvailableModels(text) {
  const m = String(text || "").match(/available models:\s*([\s\S]+)/i);
  if (!m) return [];
  return m[1]
    .split(",")
    .map((s) => s.trim().replace(/[.;]+$/g, ""))
    .filter((s) => s.length > 0 && !/\s/.test(s));
}

export function parseModel(raw) {
  const id = String(raw || "").trim();
  const lower = id.toLowerCase();
  const family = detectFamily(lower);
  const version = parseVersion(lower, family);
  const remainder = remainderTokens(lower, family);
  return {
    raw: id,
    family,
    version,
    effort: parseEffort(remainder),
    fast: remainder.includes("fast"),
    thinking: remainder.includes("thinking"),
  };
}

export function preferSlow(model) {
  const m = String(model || "").trim();
  if (!m || m === AUTO_MODEL) return m;
  return m.endsWith("-fast") ? m.slice(0, -"-fast".length) : m;
}

export function resolveFallbackChain(opts) {
  const specs = opts.fallbackSpecs;
  if (!specs?.length) return [];
  const primary = String(opts.primaryModel || "").trim();
  if (!primary) return [];
  const available = parseAvailableModels(opts.errorText || "");
  const tried = new Set(
    [...(opts.tried || []), primary].map((s) => String(s).trim()).filter(Boolean),
  );
  const parsedPrimary = parseModel(primary);
  const out = [];
  for (const spec of specs) {
    let resolved = resolveSpec(spec, parsedPrimary, available);
    if (opts.slow && resolved) resolved = preferSlow(resolved);
    if (!resolved || tried.has(resolved)) continue;
    tried.add(resolved);
    out.push(resolved);
  }
  return out;
}

function detectFamily(lower) {
  if (lower === AUTO_MODEL || lower === "latest") return "auto";
  if (lower.includes("grok")) return "grok";
  if (/sonnet-5\b/.test(lower) || lower.includes("claude-sonnet-5")) return "sonnet5";
  if (/(^|-)sol(-|$)/.test(lower)) return "sol";
  return "other";
}

function parseVersion(lower, family) {
  let m = null;
  if (family === "grok") m = lower.match(/grok-(\d+(?:\.\d+)*)/);
  else if (family === "sonnet5") m = lower.match(/sonnet-(\d+(?:[.-]\d+)*)/);
  else if (family === "sol") m = lower.match(/gpt-(\d+(?:\.\d+)*)-sol/);
  else m = lower.match(/(\d+(?:\.\d+)+)/);
  if (!m) return [];
  return m[1]
    .split(/[.-]/)
    .map((n) => Number(n))
    .filter((n) => Number.isFinite(n));
}

function remainderTokens(lower, family) {
  let rest = lower;
  if (family === "grok") rest = rest.replace(/^cursor-grok-\d+(?:\.\d+)*/, "");
  else if (family === "sonnet5") rest = rest.replace(/^claude-sonnet-\d+(?:[.-]\d+)*/, "");
  else if (family === "sol") rest = rest.replace(/^gpt-\d+(?:\.\d+)*-sol/, "");
  return rest.split("-").filter(Boolean);
}

function parseEffort(tokens) {
  const joined = tokens.join("-");
  for (const effort of EFFORTS) {
    if (tokens.includes(effort) || joined.includes(effort)) return effort;
  }
  return "high";
}

function versionRank(version) {
  return (version[0] ?? 0) * 1_000_000 + (version[1] ?? 0) * 1_000 + (version[2] ?? 0);
}

function effortIndex(effort) {
  return EFFORTS.indexOf(effort);
}

function resolveSpec(spec, primary, available) {
  const token = String(spec || "").trim();
  if (!token) return undefined;
  const kind = token.toLowerCase();
  if (kind === "latest") return pickLatestSameOptions(primary, available);
  if (kind === "sonnet" || kind === "sonnet-5" || kind === "claude-sonnet-5") {
    return pickFamilyMatch("sonnet5", primary, available) ?? defaultSonnet(primary);
  }
  if (kind === "sol" || kind === "gpt-sol" || kind === "gpt-5.6-sol") {
    return pickFamilyMatch("sol", primary, available) ?? defaultSol(primary);
  }
  if (kind === AUTO_MODEL) return AUTO_MODEL;
  if (!available.length) return token;
  if (available.includes(token)) return token;
  const parsed = parseModel(token);
  if (parsed.family !== "other" && parsed.family !== "auto") {
    return pickFamilyMatch(parsed.family, parsed, available);
  }
  return undefined;
}

function pickLatestSameOptions(primary, available) {
  if (!available.length) return AUTO_MODEL;
  if (primary.family === "auto" || primary.family === "other") return AUTO_MODEL;
  const newer = available
    .map(parseModel)
    .filter(
      (m) =>
        m.family === primary.family &&
        versionRank(m.version) > versionRank(primary.version),
    );
  if (!newer.length) return undefined;
  const maxVer = Math.max(...newer.map((m) => versionRank(m.version)));
  const newest = newer.filter((m) => versionRank(m.version) === maxVer);
  return pickBestOptions(primary, newest)?.raw;
}

function pickFamilyMatch(family, primary, available) {
  if (family === "auto" || family === "other") return undefined;
  const candidates = available
    .map(parseModel)
    .filter((m) => m.family === family && m.raw !== primary.raw);
  if (!candidates.length) return undefined;
  const maxVer = Math.max(...candidates.map((m) => versionRank(m.version)));
  const newest = candidates.filter((m) => versionRank(m.version) === maxVer);
  return pickBestOptions(primary, newest)?.raw;
}

function pickBestOptions(primary, candidates) {
  if (!candidates.length) return undefined;
  const familyHasFast = candidates.some((m) => m.fast);
  const scored = candidates.map((cand) => ({
    cand,
    score: optionScore(primary, cand, familyHasFast),
  }));
  scored.sort((a, b) => b.score - a.score);
  return scored[0]?.cand;
}

function optionScore(primary, cand, familyHasFast) {
  let score = 0;
  if (cand.effort === primary.effort) score += 100;
  else {
    score += Math.max(
      0,
      40 - Math.abs(effortIndex(cand.effort) - effortIndex(primary.effort)) * 8,
    );
  }
  if (cand.fast === primary.fast) score += 40;
  else if (!familyHasFast) score += 28;
  if (cand.thinking === primary.thinking) score += 20;
  else if (!primary.thinking && cand.thinking) score += 30;
  return score;
}

function mapConstructedEffort(effort) {
  if (effort === "extra-high") return "xhigh";
  if (effort === "minimal" || effort === "none") return "medium";
  return effort;
}

function defaultSonnet(primary) {
  const effort = mapConstructedEffort(primary.effort);
  let id = `claude-sonnet-5-thinking-${effort}`;
  if (primary.fast) id += "-fast";
  return id;
}

function defaultSol(primary) {
  const effort = mapConstructedEffort(primary.effort);
  let id = `gpt-5.6-sol-${effort}`;
  if (primary.fast) id += "-fast";
  return id;
}

export function parseSpecs(raw) {
  if (raw === undefined || raw === null) return [...DEFAULT_SPECS];
  const value = String(raw).trim();
  if (!value) return [...DEFAULT_SPECS];
  if (/^(off|none|false|disabled)$/i.test(value)) return [];
  return value
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function parseArgs(argv) {
  const out = { primary: "", errorFile: "", errorText: "", specs: "", slow: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--primary") out.primary = argv[++i] || "";
    else if (a === "--error-file") out.errorFile = argv[++i] || "";
    else if (a === "--error-text") out.errorText = argv[++i] || "";
    else if (a === "--specs") out.specs = argv[++i] || "";
    else if (a === "--slow") out.slow = true;
  }
  return out;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const errorText = args.errorFile
    ? fs.readFileSync(args.errorFile, "utf8")
    : args.errorText;
  if (!isRetryableModelError(errorText)) process.exit(0);
  const specs = parseSpecs(args.specs === "" ? undefined : args.specs);
  const chain = resolveFallbackChain({
    primaryModel: args.primary,
    fallbackSpecs: specs,
    errorText,
    slow: args.slow,
  });
  for (const id of chain) process.stdout.write(`${id}\n`);
}

const isMain =
  process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) main();
