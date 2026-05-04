#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const casesPath = path.join(__dirname, "skill-cases.json");
const artifactsDir = path.join(__dirname, "artifacts");
const resultsPath = path.join(artifactsDir, "results.json");

function parseArgs(argv) {
  const args = {
    caseId: null,
    model: null,
    codexBin: process.env.CODEX_BIN || "codex",
    list: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];

    if (arg === "--case") {
      args.caseId = argv[++i];
    } else if (arg === "--model") {
      args.model = argv[++i];
    } else if (arg === "--codex-bin") {
      args.codexBin = argv[++i];
    } else if (arg === "--list") {
      args.list = true;
    } else if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return args;
}

function printHelp() {
  console.log(`Usage: node evals/run-skill-evals.mjs [options]

Options:
  --case <id>          Run one case from evals/skill-cases.json
  --model <model>      Pass a specific model to codex exec
  --codex-bin <path>   Codex binary to run, defaults to CODEX_BIN or codex
  --list               List case ids without running
`);
}

function loadCases() {
  const cases = JSON.parse(readFileSync(casesPath, "utf8"));

  if (!Array.isArray(cases)) {
    throw new Error("evals/skill-cases.json must contain an array");
  }

  return cases;
}

function runCodex(testCase, args) {
  mkdirSync(artifactsDir, { recursive: true });

  const jsonlPath = path.join(artifactsDir, `${testCase.id}.jsonl`);
  const finalPath = path.join(artifactsDir, `${testCase.id}.final.txt`);
  const sandbox = testCase.sandbox || "read-only";
  const codexArgs = [
    "exec",
    "--json",
    "--cd",
    repoRoot,
    "--sandbox",
    sandbox,
    "-o",
    finalPath,
  ];

  if (args.model) {
    codexArgs.push("--model", args.model);
  }

  codexArgs.push(testCase.prompt);

  const startedAt = new Date().toISOString();
  const res = spawnSync(args.codexBin, codexArgs, {
    cwd: repoRoot,
    encoding: "utf8",
    maxBuffer: 1024 * 1024 * 50,
  });

  writeFileSync(jsonlPath, res.stdout || "", "utf8");

  return {
    id: testCase.id,
    skill: testCase.skill,
    should_trigger: testCase.should_trigger,
    started_at: startedAt,
    finished_at: new Date().toISOString(),
    exit_code: res.status ?? 1,
    signal: res.signal,
    jsonl_path: path.relative(repoRoot, jsonlPath),
    final_path: path.relative(repoRoot, finalPath),
    stderr: res.stderr || "",
  };
}

function parseJsonl(jsonlText) {
  const events = [];
  const parseErrors = [];

  for (const [index, line] of jsonlText.split("\n").entries()) {
    if (!line.trim()) {
      continue;
    }

    try {
      events.push(JSON.parse(line));
    } catch (error) {
      parseErrors.push({ line: index + 1, message: error.message });
    }
  }

  return { events, parseErrors };
}

function eventText(events) {
  return events.map((event) => JSON.stringify(event)).join("\n");
}

function commandExecutions(events) {
  return events.filter((event) => {
    const item = event.item || event.data?.item || {};
    return item.type === "command_execution" || event.type === "exec_command";
  });
}

function includesAll(haystack, needles = []) {
  return needles.map((needle) => ({
    needle,
    pass: haystack.toLowerCase().includes(String(needle).toLowerCase()),
  }));
}

function excludesAll(haystack, needles = []) {
  return needles.map((needle) => ({
    needle,
    pass: !haystack.toLowerCase().includes(String(needle).toLowerCase()),
  }));
}

function scoreCase(testCase, run) {
  const jsonl = existsSync(path.join(repoRoot, run.jsonl_path))
    ? readFileSync(path.join(repoRoot, run.jsonl_path), "utf8")
    : "";
  const finalText = existsSync(path.join(repoRoot, run.final_path))
    ? readFileSync(path.join(repoRoot, run.final_path), "utf8")
    : "";
  const { events, parseErrors } = parseJsonl(jsonl);
  const trace = eventText(events);
  const commands = commandExecutions(events);

  const checks = [
    {
      id: "exit_code_zero",
      pass: run.exit_code === 0,
      notes: `exit_code=${run.exit_code}`,
    },
    {
      id: "jsonl_parseable",
      pass: parseErrors.length === 0,
      notes: parseErrors.length === 0 ? "ok" : JSON.stringify(parseErrors.slice(0, 3)),
    },
    ...includesAll(finalText, testCase.expected_final_substrings).map((check) => ({
      id: `final_contains:${check.needle}`,
      pass: check.pass,
      notes: check.pass ? "found" : "missing",
    })),
    ...includesAll(trace, testCase.expected_trace_substrings).map((check) => ({
      id: `trace_contains:${check.needle}`,
      pass: check.pass,
      notes: check.pass ? "found" : "missing",
    })),
    ...excludesAll(trace, testCase.forbidden_trace_substrings).map((check) => ({
      id: `trace_excludes:${check.needle}`,
      pass: check.pass,
      notes: check.pass ? "absent" : "present",
    })),
  ];

  if (Number.isInteger(testCase.max_command_executions)) {
    checks.push({
      id: "max_command_executions",
      pass: commands.length <= testCase.max_command_executions,
      notes: `${commands.length}/${testCase.max_command_executions}`,
    });
  }

  const passed = checks.every((check) => check.pass);

  return {
    ...run,
    passed,
    command_execution_count: commands.length,
    checks,
  };
}

function summarize(results) {
  const passed = results.filter((result) => result.passed).length;
  const failed = results.length - passed;

  console.log(`\nSkill evals: ${passed}/${results.length} passed`);

  for (const result of results) {
    const marker = result.passed ? "PASS" : "FAIL";
    console.log(`${marker} ${result.id} (${result.skill})`);

    if (!result.passed) {
      for (const check of result.checks.filter((item) => !item.pass)) {
        console.log(`  - ${check.id}: ${check.notes}`);
      }
    }
  }

  return failed === 0 ? 0 : 1;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  let cases = loadCases();

  if (args.list) {
    for (const testCase of cases) {
      console.log(`${testCase.id}\t${testCase.skill}`);
    }
    return 0;
  }

  if (args.caseId) {
    cases = cases.filter((testCase) => testCase.id === args.caseId);

    if (cases.length === 0) {
      throw new Error(`No eval case found for id: ${args.caseId}`);
    }
  }

  mkdirSync(artifactsDir, { recursive: true });

  const results = cases.map((testCase) => {
    const run = runCodex(testCase, args);
    return scoreCase(testCase, run);
  });

  writeFileSync(resultsPath, `${JSON.stringify(results, null, 2)}\n`, "utf8");

  return summarize(results);
}

try {
  process.exitCode = main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
