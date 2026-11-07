---
name: generate-rule
description: "Generates concise, clarified, and machine-enforceable rules across a set of files by spawning multi-directional subagents to produce candidate tries (default: 2 per direction), minimizing cross-file redundancies, enforcing structural consistency, and synthesizing champion rules in the repository rule style."
disable-model-invocation: true
context: fork
---

# Rule Generation & Distillation Skill

Def: Purpose → Systematically design, evaluate, harmonize, and distill high-density, machine-enforceable rules across single or multiple rule files for AI agent platforms by inspecting target files, minimizing cross-file redundancies, maximizing structural consistency, generating candidate iterations across 6 orthogonal design paradigms (configurable tries, default 2 per direction), and synthesizing champion rule sets.

Section: Invocation Parameters

- `[target-files]`: Required. Single file path, list of file paths, or glob pattern of rule files to inspect, create, refactor, distill, or harmonize (e.g., `providers/shared/rules/*.md` or `rules/40-lang-standard-*.md`). Rule topics, domain scopes, tool bindings, and operational constraints are derived directly from the files themselves and workspace architecture.
- `[additional-constraints]`: Optional. Supplementary operational constraints, requirement deltas, or tool bindings not discoverable from `[target-files]`.
- `[tries]`: Optional. Number of candidate tries to generate per direction. Defaults to `2` (yielding 12 total candidate variations per file across 6 orthogonal paradigms: 6 directions × 2 tries).

Section: Execution Flow

Step: 1. Target Inspection & Cross-File Constraint Mapping:
- Rule: Multi-File Context Extraction: Inspect each file in `[target-files]` (or target directory/hierarchy if new) to autonomously extract individual domain scopes, existing constraints, tool bindings, and structural relationships.
- Rule: Cross-File Redundancy & Conflict Detection: Build an aggregate cross-file constraint matrix. Identify duplicated rules, overlapping definitions, shared abstractions, and semantic inconsistencies across files.
- Rule: Hierarchical Layering & Checklist Compilation: Partition constraints into universal common invariants vs specialized domain expansions (enforcing non-redundant hierarchical supplementation). Merge with `[additional-constraints]` into an explicit numbered checklist ($C_1, C_2, \dots, C_n$) mapping constraints to their designated target files. Every candidate rule set MUST achieve 100% Zero Context Loss against this checklist.
- Rule: Style Verification: Candidates use one imperative bullet per rule with its condition, in plain words, with no tags, rule IDs, rationale, or symbolic connectives; examples appear only where a rule is ambiguous without them, and exact templates (log functions, helper macros) stay verbatim as the rule.
- Rule: No Cross-References: Candidates never name other rule files, tool names, or load orders; the platform loads rules by trigger.

Step: 2. Multi-Direction Subagent Dispatch:
- Rule: Configurable Multi-Try Execution: Concurrently invoke specialized subagents using `invoke_subagent` across 6 mutually exclusive, expandable design directions, instructing each subagent to produce exactly `[tries]` distinct candidate tries per target file (default: 2 tries per direction = 12 candidate tries per file):
  1. Direction 1 (Atomic Invariants): Compress constraints into the fewest atomic, condition-qualified imperatives.
  2. Direction 2 (Sequential Lifecycle Phasing): Structure rules along a chronological execution pipeline (Discovery/Pre-flight Gate → Transformation Gate → Verification/Commit Gate).
  3. Direction 3 (Normative Guardrails & Negative Fences): Enforce rigid RFC-2119 / ISO modals (`MUST NOT...; MUST...; SHALL NOT...`), assertion boundaries, anti-patterns, and anti-hallucination fences.
  4. Direction 4 (Algorithmic Procedures & Decision Matrices): Formulate rules as deterministic pseudocode blocks (`FUNCTION Resolve...`, `MATCH/CASE`), truth tables, and predicate decision matrices.
  5. Direction 5 (Interface Contracts & Pre/Post Conditions): Formulate rules as strict API-style specifications with explicit precondition assertions, input validation contracts, and postcondition verification guarantees.
  6. Direction 6 (Failure Modes & Resilient Fallbacks): Formulate rules centered on edge-case detection, recovery branching, graceful degradation, and exception-handling workflows.
- Rule: Cross-File Harmonization Invariant: Subagents MUST ensure shared terminology and structure are strictly consistent across all candidate files in the set.
- Rule: Full Granularity: Every try MUST contain the complete, ready-to-use markdown rule text with exact tool and parameter names in backticks.

Step: 3. Multi-Dimensional Comparative Analysis:
- Rule: Multi-File Benchmark Audit: Benchmark all candidate tries across 5 orthogonal evaluation dimensions:
  1. **Token Economy & Cross-File Footprint**: Quantitative audit of line count, word count, character count, token compression ratio, and cross-file redundancy reduction vs baseline.
  2. **Constraint Coverage & Deduplication Audit**: 100% Zero Context Loss verification against the cross-file checklist created in Step 1, verifying zero duplicated constraints between common and specialized files.
  3. **Cross-File Cohesion & LLM Ergonomics**: Evaluate holistic coherence, consistent naming conventions across files, instruction-following sharpness, and absence of conversational padding.
  4. **Behavioral Effect**: Run `tests/eval/run.sh --baseline` (agy flash) on cases covering the changed rules; prefer candidates that pass with the plugin and fail without it.
  5. **Cross-Platform Compatibility**: Validate native AST and Markdown parsing across Antigravity (agy) and Claude Code.

Step: 4. Final Champion Synthesis & Cross-File Harmonization:
- Rule: Attribute Merging & Cross-File Alignment: Synthesize the highest-scoring qualities into champion rule sets for each target file, ensuring global structural symmetry, and unified terminology across the entire file set.
- Rule: Cross-File Redundancy Elimination: Isolate shared invariants into common files and ensure specialized files contain non-redundant expansions without restating higher-level rules.
- Rule: Context Window & Token Density Optimization: Eliminate conversational fluff, narrative explanations, duplicate tables, and redundant boilerplate while preserving 100% of semantic constraints.
- Rule: Coverage Record: Update `docs/rule-coverage.md` for every moved, conditioned, corrected, or removed requirement.

Step: 5. Authorization & Multi-File Application:
- Rule: User Precedence Check: Present the cross-file comparative analysis, redundancy reduction metrics, and finalized champion rule sets to the user.
- Rule: Atomic Batch Application: Upon user authorization, write champion rules to their respective target files, register any updated files in compiler manifests, and execute compilation scripts (`scripts/compile.sh`).
