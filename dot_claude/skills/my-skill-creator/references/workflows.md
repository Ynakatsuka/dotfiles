# Workflow Patterns

## Sequential Workflows

For complex tasks, break operations into clear, sequential steps. It is often helpful to give Claude an overview of the process towards the beginning of SKILL.md:

```markdown
Filling a PDF form involves these steps:

1. Analyze the form (run analyze_form.py)
2. Create field mapping (edit fields.json)
3. Validate mapping (run validate_fields.py)
4. Fill the form (run fill_form.py)
5. Verify output (run verify_output.py)
```

## Conditional Workflows

For tasks with branching logic, guide Claude through decision points:

```markdown
1. Determine the modification type:
   **Creating new content?** → Follow "Creation workflow" below
   **Editing existing content?** → Follow "Editing workflow" below

2. Creation workflow: [steps]
3. Editing workflow: [steps]
```

## Artifact Pipeline Pattern

For skills that produce deliverables (reports, datasets, generated files), structure the workflow as a clear pipeline:

```markdown
## Workflow: Generate Monthly Analytics Report

### Step 1: Install Dependencies
Run `scripts/setup.sh` to install required packages.
If setup fails, stop and report the error.

### Step 2: Fetch Data
Run `scripts/fetch_data.py --month {MONTH} --year {YEAR}`
Validate: output file exists at `data/raw_{MONTH}.csv`

### Step 3: Process and Transform
Run `scripts/transform.py --input data/raw_{MONTH}.csv`
Validate: no errors in stderr, output at `data/processed_{MONTH}.csv`

### Step 4: Generate Artifact
Run `scripts/render_report.py --data data/processed_{MONTH}.csv --template assets/report-template.md`
Output: `output/report_{MONTH}_{YEAR}.md`

### Step 5: Verify Output
Check that the output file exists, is non-empty, and contains expected sections.
```

Key techniques:
- Each step has explicit validation before proceeding
- Network-dependent steps (fetch) are isolated from local processing steps
- Output location is predictable and parameterized
- Failure at any step halts the pipeline with a clear error message

This pattern is particularly effective for:
- Report generation workflows
- Data extraction and transformation pipelines
- Code generation with compilation verification
- Document assembly from multiple sources
