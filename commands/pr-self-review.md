# PR Self-Review Workflow

## Your task

Systematically review the user's recently created PR with a focus on Python/ML and dbt/SQL code quality. Follow this comprehensive review workflow:

### 1. Gather PR Information

First, identify and fetch the most recent PR created by the user:

```bash
# Get user's recent PRs
GITHUB_USER=$(gh api user -q .login)
gh pr list --author "$GITHUB_USER" --limit 5 --json number,title,url,createdAt,draft,headRefName

# Select the most recent PR
PR_NUMBER=[Selected PR number]
PR_BRANCH=$(gh pr view $PR_NUMBER --json headRefName -q .headRefName)

# Fetch PR details
gh pr view $PR_NUMBER --json title,body,files,commits,additions,deletions,changedFiles

# Get file changes
gh pr diff $PR_NUMBER --name-only
```

### 2. Automated Quality Checks

Run automated checks before manual review:

```bash
# Switch to PR branch
git checkout $PR_BRANCH
git pull origin $PR_BRANCH

# General checks
echo "=== Security & Dependencies ==="
# Check for secrets
git secrets --scan
# Check dependencies
pip-audit || uv pip audit
```

### 3. Code Review Checklist

Review each file systematically using this checklist:

## 🔴 Critical Review Points

### 3.1 Logic Correctness

#### Python/Machine Learning

```markdown
- [ ] **Data Leakage Check**
  - No future information in features
  - Proper train/test split before preprocessing
  - No test data statistics in training

- [ ] **Model Implementation**
  - Correct loss function for the task
  - Appropriate metrics for evaluation
  - Proper cross-validation strategy
  - Reproducibility (random seeds)

- [ ] **Data Processing**
  - Handling of missing values
  - Outlier treatment consistency
  - Feature scaling after split
  - Categorical encoding strategy
```

#### dbt/SQL

```markdown
- [ ] **Query Logic**
  - No duplicate counting (check GROUP BY)
  - Correct JOIN type (LEFT vs INNER vs FULL)
  - Proper NULL handling in aggregations
  - Window function partitions and ordering

- [ ] **Data Quality**
  - Primary key uniqueness
  - Referential integrity
  - Date range filters
  - Handling of edge cases
```

### 3.2 Design Patterns & Architecture

```markdown
- [ ] **Code Structure**
  - Single Responsibility Principle
  - DRY implementation
  - Appropriate abstraction levels
  - Clear separation of concerns

- [ ] **Python Specific**
  - Type hints on all functions
  - Dataclasses for data structures
  - Context managers for resources
  - Proper exception handling

- [ ] **SQL/dbt Specific**
  - CTEs for readability
  - Modular transformations
  - Proper model materialization
  - Incremental strategy if applicable
```

### 3.3 Testing

```markdown
- [ ] **Test Coverage**
  - All new functions have tests
  - Edge cases covered
  - Happy path and error cases
  - Integration tests where needed

- [ ] **Test Quality**
  - Tests are independent
  - Clear test names
  - Proper use of fixtures/mocks
  - Assertions are specific
```

## 🟡 Important Review Points

### 3.4 Performance

#### Python Performance

```python
# Check for common performance issues
- [ ] Vectorized operations (numpy/pandas)
- [ ] Avoiding loops where possible
- [ ] Efficient data structures
- [ ] Memory usage in large datasets
- [ ] Batch processing implementation
```

#### SQL Performance

```sql
-- Check for query optimization
- [ ] Proper indexing strategy
- [ ] Avoiding SELECT *
- [ ] Efficient JOIN order
- [ ] Partition pruning
- [ ] Materialization strategy
```

### 3.5 Security & Best Practices

```markdown
- [ ] **Security**
  - No hardcoded credentials
  - Input validation
  - SQL injection prevention
  - Secure random for crypto

- [ ] **Configuration**
  - Environment variables used
  - Config files in .gitignore
  - Secrets management
  - Feature flags if needed
```

### 3.6 Database Design & Multi-tenancy

```markdown
- [ ] **Database Design Principles**
  - Proper normalization (3NF where appropriate)
  - Consistent naming conventions
  - Appropriate indexes for queries
  - Foreign key constraints defined
  - Audit columns (created_at, updated_at, etc.)
  - Soft delete strategy if applicable

- [ ] **Multi-tenant Architecture**
  - Clear tenant isolation strategy
  - Parameterized tenant identification
  - No hardcoded client-specific logic
  - Abstraction layer for schema differences
  - Configuration-driven behavior

- [ ] **Query Abstraction Patterns**
  - Repository pattern implementation
  - Query builder for dynamic conditions
  - Client-specific mapping configuration
  - Common interface despite schema variations
```

#### Example: Multi-tenant Query Pattern

```python
class BaseRepository(ABC):
    """Abstract repository for multi-tenant queries"""
    
    @abstractmethod
    def get_table_mapping(self, client_id: str) -> Dict[str, str]:
        """Get client-specific table/column mappings"""
        pass
    
    def build_query(self, client_id: str, base_query: str) -> str:
        """Build client-specific query from base template"""
        mapping = self.get_table_mapping(client_id)
        return base_query.format(**mapping)

# Good: Abstracted query
class OrderRepository(BaseRepository):
    def get_orders(self, client_id: str, filters: Dict) -> List[Order]:
        base_query = """
        SELECT {order_id_col}, {customer_col}, {amount_col}
        FROM {order_table}
        WHERE {tenant_col} = :tenant_id
        """
        query = self.build_query(client_id, base_query)
        # Execute with client-specific mappings

# Bad: Hardcoded client logic
def get_orders_bad(client_id: str):
    if client_id == "client_a":
        query = "SELECT order_id, cust_name FROM orders_a"
    elif client_id == "client_b":
        query = "SELECT id, customer FROM client_b_orders"
    # This doesn't scale!
```

#### dbt Multi-tenant Patterns

```sql
-- Good: Using variables for client-specific logic
{% set client_config = var('client_configs')[var('client_id')] %}

WITH base_orders AS (
    SELECT 
        {{ client_config.order_id_column }} AS order_id,
        {{ client_config.customer_column }} AS customer_name,
        {{ client_config.amount_column }} AS amount
    FROM {{ ref(client_config.order_table) }}
    WHERE {{ client_config.tenant_column }} = '{{ var("client_id") }}'
)

-- Bad: Hardcoded client conditions
WITH orders AS (
    SELECT *
    FROM {{ ref('orders') }}
    WHERE 
        {% if var('client_id') == 'client_a' %}
            tenant_id = 'A' AND status != 'DELETED'
        {% elif var('client_id') == 'client_b' %}
            client_code = 'B' AND is_active = true
        {% endif %}
    -- This becomes unmaintainable quickly!
)
```

## 4. Detailed File Review

For each changed file, document findings:

```markdown
## File: [path/to/file]

### Summary
- Purpose: [What this file does]
- Changes: [Key modifications]
- Impact: [Affected components]

### Issues Found

#### 🔴 Critical Issues

1. **[Issue Title]**
   - Location: Line X-Y
   - Problem: [Description]
   - Suggestion: [How to fix]
   ```python
   # Current code
   [problematic code]
   
   # Suggested fix
   [improved code]
   ```

#### 🟡 Improvements

1. **[Improvement Title]**
   - Location: Line X-Y
   - Current: [Current approach]
   - Better: [Suggested approach]

#### 🔵 Considerations

1. **[Consider Title]**
   - Future enhancement possibility
   - Alternative approaches

## 5. Special Focus Areas

### Database Design Review

```sql
-- Database design checks
-- 1. Check for missing indexes on foreign keys
SELECT 
    'missing_fk_index' as issue_type,
    table_name,
    column_name,
    'Foreign key columns should have indexes' as recommendation
FROM information_schema.key_column_usage
WHERE constraint_name LIKE 'fk_%'
    AND NOT EXISTS (
        SELECT 1 FROM information_schema.statistics
        WHERE table_name = key_column_usage.table_name
            AND column_name = key_column_usage.column_name
    );

-- 2. Check for inconsistent naming
SELECT 
    'naming_inconsistency' as issue_type,
    table_name,
    column_name,
    CASE
        WHEN column_name NOT LIKE '%_id' AND data_type = 'bigint' 
            THEN 'ID columns should end with _id'
        WHEN column_name NOT LIKE '%_at' AND column_name IN ('created', 'updated', 'deleted')
            THEN 'Timestamp columns should end with _at'
        ELSE 'Check naming convention'
    END as recommendation
FROM information_schema.columns
WHERE table_schema = 'your_schema';
```

## 6. Review Summary Template

After completing the review, create a summary:

```markdown
# PR Review Summary: [PR Title]

## Overview
- **PR #**: [Number]
- **Author**: [Username]
- **Changes**: +[additions] -[deletions] across [files] files
- **Review Date**: [Date]

## Review Results

### 🔴 Must Fix (X issues)
1. [Critical issue summary]
2. [Another critical issue]

### 🟡 Should Improve (Y suggestions)
1. [Important improvement]
2. [Performance optimization]

### 🔵 Consider (Z items)
1. [Future enhancement]
2. [Alternative approach]

### ✅ Good Practices Found
1. [Positive feedback]
2. [Well-implemented feature]

## Special Focus Areas

### Database Design
- [ ] Normalization: [Appropriate/Issues found]
- [ ] Indexing strategy: [Optimized/Needs improvement]
- [ ] Naming conventions: [Consistent/Inconsistent]
- [ ] Constraints: [Properly defined/Missing]

### Multi-tenant Compatibility
- [ ] Client abstraction: [Well abstracted/Hardcoded logic found]
- [ ] Schema flexibility: [Configurable/Rigid]
- [ ] Query patterns: [Reusable/Client-specific]
- [ ] Scalability: [Ready for new clients/Needs refactoring]

## Automated Check Results
- Linting: [PASS/FAIL]
- Type checking: [PASS/FAIL]
- Tests: [X/Y passing]
- Security scan: [PASS/FAIL]

## Recommendation
[ ] Approve as-is
[ ] Approve with minor changes
[ ] Request changes
[ ] Needs discussion

## Detailed Feedback
[Provide file-by-file feedback here]
```

## 7. Follow-up Actions

Based on review findings:

```bash
# Create GitHub review
gh pr review $PR_NUMBER --body-file review-summary.md --comment

# Or request changes
gh pr review $PR_NUMBER --body-file review-summary.md --request-changes

# Add inline comments
gh pr review $PR_NUMBER --body-file review-summary.md --comment \
  --comment "path/to/file.py:15:Security issue: API key exposed"
```

## Important Notes

- **Be constructive**: Focus on improvements, not criticism
- **Provide examples**: Show better implementations
- **Explain why**: Don't just point out issues
- **Acknowledge good work**: Highlight well-written code
- **Consider context**: Understand time/scope constraints
- **Use automation**: Let tools catch basic issues
- **Focus on impact**: Prioritize high-impact problems
