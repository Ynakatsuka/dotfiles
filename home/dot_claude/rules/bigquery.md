---
paths: "**/*.sql"
---

## BigQuery

- Interact with BigQuery **exclusively** via the `bq` command-line tool.
- **Always** explicitly display the current settings (`project_id`, `account address`) **before** executing any query.
- **Mandatory:** Perform a dry run (`--dry_run`) and seek user confirmation **if** a query is estimated to scan over 50GB of data.
- For exploratory analyses, **strongly prefer** using `TABLESAMPLE SYSTEM (1 PERCENT)` to limit costs and query time, unless full data scanning is explicitly required and approved.

### SQL Writing Principles

- **Use Common Table Expressions (CTEs):**
    - Do not use subqueries. Structure your query with CTEs.
- **Name Initial CTEs `import_{dataset_name}_{table_name}`:**
    - The first CTEs that select from a source table should be named using this convention.
    - **Constraints:**
        - (Must) Each `import_` CTE must reference only a single source table.
        - (Should) Avoid including complex logic in these CTEs. They are for importing raw data.
- **Name Transformation CTEs `logic_{purpose}`:**
    - CTEs that perform `JOIN`s, aggregations, or other transformations should be named with a `logic_` prefix.
    - These CTEs must only reference `import_` CTEs or other `logic_` CTEs.
- **Name the Final CTE `final`:**
    - The last CTE in the query, representing the final dataset, must be named `final`.
    - The final statement of the query must be `SELECT * FROM final`.
- **Use Japanese for SQL Comments:**
    - Add comments within the SQL query to explain the "why" behind specific logic or transformations. Note: This is a specific exception to the general rule that all code comments must be in English. SQL comments MUST be in Japanese.
- **Casing Convention:**
    - Use `UPPERCASE` for SQL reserved keywords (e.g., `SELECT`, `FROM`, `WITH`).
    - Use `lowercase` for table names, column names, and CTE names.
