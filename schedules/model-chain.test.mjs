import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  AUTO_MODEL,
  isRetryableModelError,
  parseAvailableModels,
  resolveFallbackChain,
} from "./model-chain.mjs";

const CHRISTINA_ERR = `Cannot use this model: cursor-grok-4.5-high-fast. Available models: auto, gpt-5.3-codex-low, cursor-grok-4.6-high-fast, cursor-grok-4.6-medium, cursor-grok-4.6-high, claude-sonnet-5-thinking-high, claude-sonnet-5-thinking-xhigh, claude-sonnet-5-high, gpt-5.6-sol-high, gpt-5.6-sol-high-fast, gpt-5.6-sol-medium`;

describe("model-chain", () => {
  it("treats cannot-use-this-model as retryable", () => {
    assert.equal(isRetryableModelError(CHRISTINA_ERR), true);
    assert.equal(isRetryableModelError("ENOENT workspace missing"), false);
  });

  it("parses the catalog list", () => {
    assert.ok(parseAvailableModels(CHRISTINA_ERR).includes("cursor-grok-4.6-high-fast"));
  });

  it("picks latest same-options grok, then sonnet 5, then sol", () => {
    assert.deepEqual(
      resolveFallbackChain({
        primaryModel: "cursor-grok-4.5-high-fast",
        fallbackSpecs: ["latest", "sonnet", "sol"],
        errorText: CHRISTINA_ERR,
      }),
      [
        "cursor-grok-4.6-high-fast",
        "claude-sonnet-5-thinking-high",
        "gpt-5.6-sol-high-fast",
      ],
    );
  });

  it("strips -fast for ticks", () => {
    assert.deepEqual(
      resolveFallbackChain({
        primaryModel: "cursor-grok-4.5-high-fast",
        fallbackSpecs: ["latest", "sonnet", "sol"],
        errorText: CHRISTINA_ERR,
        slow: true,
      }),
      ["cursor-grok-4.6-high", "claude-sonnet-5-thinking-high", "gpt-5.6-sol-high"],
    );
  });

  it("skips latest when already on the newest grok", () => {
    const err = `Cannot use this model: x. Available models: cursor-grok-4.6-medium, claude-sonnet-5-thinking-medium, claude-sonnet-5-thinking-high, gpt-5.6-sol-medium, gpt-5.6-sol-high`;
    assert.deepEqual(
      resolveFallbackChain({
        primaryModel: "cursor-grok-4.6-medium",
        fallbackSpecs: ["latest", "sonnet", "sol"],
        errorText: err,
        slow: true,
      }),
      ["claude-sonnet-5-thinking-medium", "gpt-5.6-sol-medium"],
    );
  });

  it("uses Auto as Latest when there is no catalog list", () => {
    assert.deepEqual(
      resolveFallbackChain({
        primaryModel: "cursor-grok-4.6-medium",
        fallbackSpecs: ["latest", "sonnet", "sol"],
        errorText: "ActionRequiredError: out of usage",
        slow: true,
      }),
      [AUTO_MODEL, "claude-sonnet-5-thinking-medium", "gpt-5.6-sol-medium"],
    );
  });
});
