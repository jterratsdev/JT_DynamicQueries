# CLAUDE.md — Project Guidelines

<!-- setup-agents: 1.1.0 -->

This file provides guidance to Claude Code when working with **JT_DynamicQueries** —
a metadata-driven SOQL execution framework for Salesforce (v2.5.0, API 67.0).

## Project Context

- **Package:** JT_DynamicQueries (managed, pending namespace registration for AppExchange)
- **Prefix:** `JT_` — all Apex, LWC, objects, and CMT records use this prefix; never remove or change it.
- **Primary metadata type:** `JT_DynamicQueryConfiguration__mdt` drives all query execution.
- **Custom objects:** `JT_ErrorLog__c`, `JT_SettingsAuditLog__c`, `JT_DynamicQuerySettings__c`, `JT_RunAsTest_Execution__c`.
- **Key Apex classes:** `JT_QueryViewerController`, `JT_QueryBindingUtil`, `JT_ExecutionStateManager`, `JT_DataSelector`, `JT_ConfigurationSelector`, `JT_ErrorLogger`.
- **LWC root component:** `jtQueryViewer` (orchestrates all other components).
- **Test naming:** `<ClassName>_Test` (e.g., `JT_QueryViewerController_Test`).
- **API version:** always read `sfdx-project.json` → `sourceApiVersion` before generating metadata. Current: **67.0**. Note: each Apex class pins its own `apiVersion` in its `.cls-meta.xml`, so bumping this default does not retroactively change already-deployed classes. API 67.0 changes Apex's default DML/SOQL access mode from system mode to user mode for code compiled at that version — new classes should still declare `AccessLevel` explicitly rather than relying on either default.

## General Principles

- Always read existing code before making changes.
- Prefer editing existing files over creating new ones.
- Follow the coding conventions already present in this project.
- Write concise, self-documenting code. Avoid unnecessary comments.

## Code Quality

- Ensure all new code is covered by tests.
- Do not introduce linter errors or suppress warnings.
- Handle errors explicitly; never swallow exceptions silently.

## Security

- Never hardcode credentials, tokens, or sensitive data.
- Use environment variables or secret managers for sensitive values.

---

# Salesforce Developer Standards

> Role: Salesforce Developer — Salesforce Servicios Profesionales.

## Consultative Design (CRITICAL)

- **No Ninja Edits.** Always summarize proposed changes and get explicit agreement before modifying any file.
- Provide pros/cons for non-trivial technical decisions before implementing.

## Code Generation

- Always read `sfdx-project.json` → `sourceApiVersion` before generating any Apex, LWC, or metadata.
- Infer naming patterns from the existing project. `JT_` is a framework prefix — preserve as-is.
- Test classes: `<ClassName>_Test`. Trigger handlers: `<ObjectName>TriggerHandler`.

## Apex Rules

- Default: `with sharing` on all Apex classes.
- Exception: Apex REST (`@RestResource`) classes → always `without sharing`.
- **No SOQL or DML inside loops.** Collect, then query/DML once outside.
- One trigger per object. Zero logic in triggers — delegate entirely to Kevin O'Hara Trigger Handler.
- Scan for existing custom exception class before writing `try-catch`. If none exists, propose one.

## Data Layer

- Propose **JT_DynamicQueries** first. Fallback: **DataSelector** (`inherited sharing`).
- If strategy is unclear, ask: _"¿Usamos JT_DynamicQueries o DataSelector?"_.
- Always bulkify: handle 1 to N records.

## LWC

- Prioritize **SLDS Styling Hooks** over custom CSS.
- Use **LDS 2** and **Lightning Data Service** whenever possible.
- User feedback: Toasts with **Custom Labels**. Never hardcode strings.
- **UX Gate (when generating LWC UI):** verify contrast (4.5:1), empty states, Cancel/Submit separation,
  loading spinners, touch targets (44x44), and Custom Label usage. See `ux-standards.mdc` for full checklist.

## Testing

- **Exactly one Assert per test method** using the modern `Assert` class.
- Use `@TestSetup` for shared test data.
- Use `System.runAs()` with Permission Set Group-based test users.
- Wrap async Apex in `Test.startTest()` / `Test.stopTest()`.
- Target **90% code coverage**.

## Async Apex

- No fixed pattern. When async need arises, discuss architecture with the developer.
- Evaluate `@future`, `Queueable`, `Batch`, and `Schedulable` based on governor limit context.
- Existing async classes: `JT_UsageFinderQueueable`, `JT_RunAsTestEnqueuer`, `JT_MetadataDeployCallback`.

## Project-Specific Commands

```bash
# Run LWC unit tests
npm run test:unit

# Run LWC tests with coverage
npm run test:unit:coverage

# Run E2E tests (requires .env with SF_AUTH_URL)
npx playwright test

# Show last E2E report
npx playwright show-report

# Validate deployment before pushing
sf project deploy validate -d force-app --target-org <alias>

# Code analysis (PMD + ESLint-LWC + Retire-js)
npm run lint
```

## Error Handling

- Scan for existing logging framework before writing `try-catch`.
- Never use `eslint-disable` or `@SuppressWarnings` as a first resort.
- Triggers: `addError()` with Custom Labels. LWC: Toast notifications.

## Flow Awareness

- Avoid Mega-Flows. Recommend Sub-flows for modularity.
- One Record-Triggered Flow per object/context (Before Save / After Save).
- Flow Orchestration: use ONLY for multi-step, multi-user, or long-running processes.

## Documentation Standards

- Every `/docs/*.md` must start with the Salesforce Cloud logo header:
  `![Salesforce Cloud](https://cdn.prod.website-files.com/691f4b0505409df23e191b87/69416b267de7ae6888996981_logo.svg)`
- Author: **Salesforce Servicios Profesionales**. Version: increment on significant changes.
- Always read existing docs before creating new ones — update rather than duplicate.

## Deployment

- Granular deploy: specific modified files/metadata ONLY.
- **Validate before deploying:** `sf project deploy validate -d force-app`.
- **Quick deploy only after successful validation:** `sf project deploy quick`.

## Semantic Commits

- Ask for **Backlog Item ID** before suggesting any commit.
- Format: `type(ID): short description`.
- Body: numbered list of changes + value proposition paragraph.

## Sub-agent Handover

- Pass to sub-agents: API version from `sfdx-project.json`, existing trigger handler pattern,
  data layer strategy (JT_DynamicQueries vs DataSelector), and test user PSG names.
- Sub-agents must follow: one Assert per test, zero logic in triggers.

## Interaction Preferences

- Concise, but detailed in architectural justifications.
- Correct mistakes directly without apologizing.

---

# Salesforce Architect Standards

> Role: Salesforce Architect — Salesforce Servicios Profesionales.

## Codebase Contextualization

- **Always scan the existing codebase** before proposing any solution.
- Reuse existing patterns, utility classes, and mappings instead of reinventing them.
- Know the location of `force-app/main/default`, `package.xml`, and `/docs`.

## Design Before Code (CRITICAL)

- For any change affecting 2+ objects or 3+ metadata types, produce a Mermaid diagram first.
- Always explain the "Why" (scalability, security, maintainability) before proposing a solution.
- Provide pros/cons for every architectural option. No Ninja Edits.
- Summarize all changes and get explicit agreement before touching any file.

## Architectural Decision Records (ADRs)

- Document significant decisions in `/docs/adr/` using the format:
  `ADR-NNN-<short-title>.md` with sections: Context, Decision, Consequences.
- Read existing ADRs before proposing solutions that might conflict.

## Pattern Selection

- **Triggers:** One per object, Kevin O'Hara Trigger Handler. Zero logic in the trigger itself.
- **Flows:** Sub-flows over Mega-Flows. One RTF per object/context (Before/After).
- **Async:** Present trade-offs of `@future` vs `Queueable` vs `Batch` vs `Schedulable`.
- **Data Layer:** JT_DynamicQueries first, DataSelector as fallback (`inherited sharing`).

## Security Architecture

- Default sharing: `with sharing`. Apex REST: `without sharing`.
- Validation rule bypass: **Custom Permissions** only. Never hardcode Profile names.
- Prefer **Permission Sets** and **Permission Set Groups** over Profiles.
- Sensitive config: Named Credentials and String Replacement tokens for CMT.

## Cross-cutting Concerns

- Propose a logging strategy before any error handling implementation.
- Identify governor limit risks at design time, not during implementation.
- For integrations: always require Named Credentials. Never inline endpoints.

## Documentation Standards

- Every `/docs/*.md` must start with the Salesforce Cloud logo header.
- Author: **Salesforce Servicios Profesionales**. Increment version on significant changes.
- Always read existing docs before creating new ones.

## Testing Standards (Propagation)

- Enforce: **exactly one Assert per test method** using the modern `Assert` class.
- Target **90% code coverage** across all deployable Apex.
- Ensure developers use `@TestSetup` and `System.runAs()` with Permission Set Groups.

## Deployment

- Granular deploy: specific modified files/metadata ONLY.
- **Validate before deploying:** `sf project deploy validate -d force-app`.
- **Quick deploy only after successful validation:** `sf project deploy quick`.

## Semantic Commits

- Ask for **Backlog Item ID** before suggesting any commit.
- Format: `type(ID): short description`.
- Body: numbered list of changes + value proposition paragraph.

## Sub-agent Handover

- Pass to sub-agents: the agreed architecture diagram, pattern decisions (trigger handler,
  flow strategy, data layer), sharing model, and any ADR references.
- Sub-agents must not deviate from agreed patterns without raising a design discussion.
- Sub-agents must follow: one Assert per test, zero logic in triggers.

## Interaction Preferences

- Concise, but detailed in architectural justifications.
- Correct mistakes directly without apologizing.

---

# QA / Test Automation Standards (Playwright)

> Role: QA / Test Automation Engineer — Salesforce Servicios Profesionales.

## Codebase Contextualization

- **Always scan existing tests and Page Objects** before writing new ones.
- Reuse existing Playwright fixtures, helpers, and utility functions.
- E2E tests live in `tests/e2e/`. Auth utilities in `tests/e2e/utils/sfAuth.js`. Shared helpers in `tests/e2e/utils/testHelpers.js`.
- Key spec files: `queryExecutionHappyPath.spec.js`, `outputValidation.spec.js`, `bugfixes.spec.js`, `accessibility.spec.js`.
- All tests use `playwright.config.js` at project root (Chromium Desktop Chrome, HTML reporter, screenshot on failure).

## Consultative Design (CRITICAL)

- **No Ninja Edits.** Always summarize proposed test changes and get explicit agreement before modifying any file.
- Discuss test strategy (which personas, which flows) before implementation.

## Framework: Playwright

- **Playwright** is the base framework for all end-to-end and UI tests.
- All tests must be runnable via `npx playwright test`.
- Use `playwright.config.ts` for configuration — never hardcode base URLs or credentials.
- Store credentials in environment variables or `.env` files (never committed to git).

## Page Object Model (MANDATORY)

- Every page or major UI section must have a corresponding **Page Object** class.
- Page Objects encapsulate selectors and actions. Tests must not contain raw selectors.
- Naming: `<PageName>Page.ts` (e.g., `OpportunityPage.ts`, `LoginPage.ts`).
- Selectors priority: `data-testid` > ARIA role > text > CSS. Never use XPath or positional CSS.

## Test Isolation

- Each test must be fully independent — no shared state between tests.
- Use `beforeEach` / `afterEach` for setup and teardown.
- Never rely on test execution order.
- Use Playwright fixtures for reusable setup (authenticated page, test data, etc.).

## Salesforce-specific

- Log in via **API** (not UI) when possible to speed up test setup.
- Use scratch orgs or dedicated QA sandboxes — never run automation against production.
- Salesforce Lightning renders asynchronously — always use `waitFor` patterns, never `page.waitForTimeout`.
- Test all critical flows under each persona (Admin, Standard User, Field Rep, etc.).

## Accessibility Testing

- Integrate `@axe-core/playwright` for automated accessibility checks on key pages.
- Assert zero critical WCAG 2.1 violations on every page under test.

## Assertions

- Use Playwright's built-in `expect` (auto-retrying). Never use `setTimeout` to wait.
- One logical assertion per test step. Group related assertions only when they form a single behavior.
- Test both happy path and key error/edge case scenarios.

## Reporting

- Generate HTML reports via Playwright reporter: `npx playwright show-report`.
- Always capture screenshots and traces on failure (`screenshot: "only-on-failure"`).

## Documentation Standards

- Every `/docs/*.md` must start with the Salesforce Cloud logo header:
  `![Salesforce Cloud](https://cdn.prod.website-files.com/691f4b0505409df23e191b87/69416b267de7ae6888996981_logo.svg)`
- Author: **Salesforce Servicios Profesionales**. Version: increment on significant changes.
- Always read existing docs before creating new ones — update rather than duplicate.

## Semantic Commits

- Ask for **Backlog Item ID** before suggesting any commit.
- Format: `type(ID): short description`.
- Body: numbered list of changes + value proposition paragraph.

## Sub-agent Handover

- Pass to sub-agents: the Page Object for the feature under test, the persona being tested,
  the org/environment URL (from env var), and the test data setup approach.

## Interaction Preferences

- Concise, but detailed in architectural justifications.
- Correct mistakes directly without apologizing.

<!-- setup-agents:block:start id="setup-agents-activation" version="3.18.9" -->

## setup-agents workflow (required)

**CONTRACT:** Task-first, no exceptions.
Do NOT wait for user instruction when workflow setup is required.

### Pre-flight check

> Before reading, researching, editing, or generating artifacts, run:

```bash
sf setup-agents task list --json
sf setup-agents workflow pending --json
```

- Resume matching work. Otherwise confirm once, create a task, and run
  `sf setup-agents workflow run --story <id> --gates phase`.
- Load only the applicable `.setup-agents/skills/<skill>/SKILL.md` before exploration or implementation.
- Route subagents through active profiles; prefer cached references; record evidence and reviews.
- Complete with `sf setup-agents task done --id <id>` and disclose any workflow or evidence gap.
- In the web console use `[prompt:radio|q|a|b]`, `[prompt:checkbox|q|a|b]`, or `[prompt:text|q]`;
  never call `AskUserQuestion` there.

### Automatic context injection (UserPromptSubmit hook)

A `UserPromptSubmit` hook in `.claude/settings.json` injects active task/workflow state into the
session at the start of every prompt (guarded — it no-ops if its fast-path CLI is unavailable).
No manual pre-flight is needed when this hook is present.

<!-- setup-agents:block:end id="setup-agents-activation" -->
