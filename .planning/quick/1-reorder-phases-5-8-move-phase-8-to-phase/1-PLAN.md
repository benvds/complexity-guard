---
phase: quick
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - .planning/ROADMAP.md
autonomous: true
must_haves:
  truths:
    - "Phase 5 is Console & JSON Output (moved from Phase 8)"
    - "Phase 6 is Cognitive Complexity (moved from Phase 5)"
    - "Phase 7 is Halstead & Structural Metrics (moved from Phase 6)"
    - "Phase 8 is Composite Health Score (moved from Phase 7)"
    - "Phase 5 depends on Phase 4 (not Phase 7)"
    - "Phase 9 SARIF depends on Phase 8 and still follows after all four reordered phases"
    - "Phases 1-4 and 9-12 are unchanged in content"
    - "Progress table reflects new phase names at positions 5-8"
    - "Execution order line is unchanged (still 1->2->...->12)"
  artifacts:
    - path: ".planning/ROADMAP.md"
      provides: "Reordered roadmap with phases 5-8 swapped"
  key_links:
    - from: "Phase 5 (Console & JSON Output)"
      to: "Phase 4"
      via: "Depends on"
      pattern: "Depends on.*Phase 4"
    - from: "Phase 6 (Cognitive Complexity)"
      to: "Phase 5"
      via: "Depends on"
      pattern: "Depends on.*Phase 5"
---

<objective>
Reorder phases 5-8 in ROADMAP.md so that Console & JSON Output (currently Phase 8) becomes Phase 5, and the three metric phases shift to 6-7-8. Update all phase numbers, dependencies, cross-references, the progress table, and the phase list accordingly.

Purpose: Moving output formatting earlier lets us see real console/JSON output sooner, providing a feedback loop for metric development. The output layer can gracefully handle `?T` optional metrics that later phases populate.
Output: Updated `.planning/ROADMAP.md` with reordered phases 5-8.
</objective>

<execution_context>
@/home/ben/.claude/get-shit-done/workflows/execute-plan.md
@/home/ben/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/STATE.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Reorder phases 5-8 in ROADMAP.md</name>
  <files>.planning/ROADMAP.md</files>
  <action>
Read `.planning/ROADMAP.md` and make the following changes. This is a careful rewrite of sections -- preserve all existing content for phases 1-4 and 9-12 exactly.

**1. Phase list (lines ~19-22) -- reorder bullet items:**
Replace:
```
- [ ] **Phase 5: Cognitive Complexity** - SonarSource metric with nesting tracking
- [ ] **Phase 6: Halstead & Structural Metrics** - Information theory and structural metrics
- [ ] **Phase 7: Composite Health Score** - Weighted scoring and letter grade assignment
- [ ] **Phase 8: Console & JSON Output** - Primary developer and CI output formats
```
With:
```
- [ ] **Phase 5: Console & JSON Output** - Primary developer and CI output formats
- [ ] **Phase 6: Cognitive Complexity** - SonarSource metric with nesting tracking
- [ ] **Phase 7: Halstead & Structural Metrics** - Information theory and structural metrics
- [ ] **Phase 8: Composite Health Score** - Weighted scoring and letter grade assignment
```

**2. Phase Details sections -- reorder the four blocks and update dependencies/criteria:**

The four Phase Detail sections must be reordered so they appear as Phase 5, 6, 7, 8 in the new assignment. For each, update:
- The heading number (### Phase N:)
- The **Depends on** line

New Phase 5 (was Phase 8): Console & JSON Output
- `**Depends on**: Phase 4`
- Update success criteria item 2: Change "health score, grade" to "health score (when available), grade (when available)" to reflect that composite scoring comes later.
- Add note to success criteria: "6. Output layer handles optional (`null`) metrics gracefully — metrics not yet computed display as `--` or are omitted"
- Keep all requirements references (OUT-CON-*, OUT-JSON-*, CI-*) unchanged.

New Phase 6 (was Phase 5): Cognitive Complexity
- `**Depends on**: Phase 5`
- Keep all requirements references (COGN-*) unchanged.
- Keep success criteria unchanged.

New Phase 7 (was Phase 6): Halstead & Structural Metrics
- `**Depends on**: Phase 6`
- Keep all requirements references (HALT-*, STRC-*) unchanged.
- Keep success criteria unchanged.

New Phase 8 (was Phase 7): Composite Health Score
- `**Depends on**: Phase 7`
- Keep all requirements references (COMP-*) unchanged.
- Keep success criteria unchanged.

**3. Phase 9 dependency update:**
Phase 9 (SARIF Output) currently says `**Depends on**: Phase 8`. After reordering, Phase 8 is Composite Health Score. SARIF logically depends on having output infrastructure (new Phase 5) AND all metrics computed (through Phase 8). Since Phase 8 is later in the chain, `**Depends on**: Phase 8` is still correct -- Phase 9 runs after all of 5-8. Leave it unchanged.

**4. Progress table -- update phase names at rows 5-8:**
Replace:
```
| 5. Cognitive Complexity | 0/TBD | Not started | - |
| 6. Halstead & Structural Metrics | 0/TBD | Not started | - |
| 7. Composite Health Score | 0/TBD | Not started | - |
| 8. Console & JSON Output | 0/TBD | Not started | - |
```
With:
```
| 5. Console & JSON Output | 0/TBD | Not started | - |
| 6. Cognitive Complexity | 0/TBD | Not started | - |
| 7. Halstead & Structural Metrics | 0/TBD | Not started | - |
| 8. Composite Health Score | 0/TBD | Not started | - |
```

**5. Execution Order line** -- no change needed. It remains `1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12`.

**6. STATE.md Phase 5 consideration update:**
In `.planning/STATE.md`, under **Phase 5 considerations**, the note about cognitive complexity arrow functions is now a Phase 6 concern. Update the heading from `**Phase 5 considerations:**` to `**Phase 6 considerations:**`.

**7. STATE.md decision update:**
In `.planning/STATE.md`, the decision line `[Phase 04-cyclomatic-complexity]: Double-analysis in main.zig acceptable for now - Phase 8 will restructure pipeline` should be updated to reference Phase 5: `Phase 5 will restructure pipeline`.

**Important: Do NOT change:**
- Any content in Phases 1-4 (completed phases)
- Any content in Phases 9-12 (beyond dependency chain, which stays correct)
- Requirement IDs (OUT-CON-*, COGN-*, etc.)
- The `*Last updated:` date at the bottom -- update it to `2026-02-14 (Phases 5-8 reordered)`
  </action>
  <verify>
Read the updated ROADMAP.md and verify:
1. Phase 5 heading says "Console & JSON Output" and depends on Phase 4
2. Phase 6 heading says "Cognitive Complexity" and depends on Phase 5
3. Phase 7 heading says "Halstead & Structural Metrics" and depends on Phase 6
4. Phase 8 heading says "Composite Health Score" and depends on Phase 7
5. Phase 9 still depends on Phase 8
6. Progress table rows 5-8 match the new names
7. Phase list bullets match the new order
8. Phases 1-4 content is unchanged
9. STATE.md references updated to reflect new phase numbers
  </verify>
  <done>
ROADMAP.md phases 5-8 are reordered: Console & JSON Output is Phase 5, Cognitive Complexity is Phase 6, Halstead & Structural is Phase 7, Composite Health Score is Phase 8. All dependencies, cross-references, and the progress table are consistent. STATE.md references are updated.
  </done>
</task>

</tasks>

<verification>
- Read ROADMAP.md and confirm phase ordering: 5=Console & JSON Output, 6=Cognitive, 7=Halstead, 8=Composite
- Confirm dependency chain: 4->5->6->7->8->9 is intact
- Confirm Phase 5 success criteria mentions handling optional/null metrics
- Confirm progress table matches new phase names
- Confirm STATE.md phase references are updated
</verification>

<success_criteria>
1. ROADMAP.md phases 5-8 contain the correct content in the new order
2. All dependency references form a valid chain (each phase depends on the previous)
3. No requirement IDs were changed or lost
4. Progress table is consistent with the new phase order
5. STATE.md references to phase numbers are updated
</success_criteria>

<output>
After completion, create `.planning/quick/1-reorder-phases-5-8-move-phase-8-to-phase/1-SUMMARY.md`
</output>
