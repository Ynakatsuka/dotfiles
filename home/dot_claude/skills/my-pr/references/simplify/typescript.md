# TypeScript / JavaScript Simplification Guide

Prefer explicit, type-safe code over clever compact code.

## Good simplification targets

- Replace duplicated conditionals with a well-named predicate when the predicate represents a real domain concept.
- Inline helpers that are used once and obscure the direct flow.
- Remove needless `async` / `await` wrappers when they do not affect stack traces, error timing, or return type contracts.
- Prefer discriminated unions over parallel boolean flags when the states are mutually exclusive.
- Remove redundant `Promise.resolve`, object spreads, or intermediate variables that only rename without clarifying.
- Replace nested ternaries with named branches or small functions.

## Avoid

- Replacing explicit checks with truthiness when `0`, `false`, `""`, or `null` have distinct meanings.
- Adding `??` / `||` defaults for missing data unless the contract explicitly defines that default.
- Catching errors to return `null`, `undefined`, or empty arrays.
- Widening types to make compile errors disappear.
- Converting readable multi-step logic into dense chained expressions.

## Verification hints

Use the project's documented commands. Common commands are `npm test`, `pnpm test`, `npm run lint`, `pnpm lint`, `npm run typecheck`, and `pnpm typecheck`, but do not invent them if the project does not define them.
