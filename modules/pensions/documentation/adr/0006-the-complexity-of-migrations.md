# 6. The Complexity of Migrations

Date: 2024-07-10

## Status

Accepted

## Context

Initially we wanted to squash down the namespaces but the nature of rails convention and folder structure does not make this trivial. Combined with challenges of getting tests to pass when moving the files around, we have opted to re-examine these changes as a secondary change.

We should determine if we want to bring over `swagger`, `db`, or any other pension-specific files and understand how they would function within the context of a rails engine.  When searching the `db` folder for the term `:saved_claims` we will see that some migrations are dependent on other columns and modules. This means that our record keeping is inherently broken for the scaffolding timeline. A practical approach is that we should create new migrations that check for the existing migration record and do a complete reinstall of the table if one is not provided. Increasing complexity and possible limited by the tooling available, If we did not account for a complete reinstall then we should be able to detect the state of the tables and correct the column structure.

We found that some of the systems should be modularized and that refactoring these in future iterations could provide us with some updates to move namespaces out of root and moving them to engines.

We want to maintain the code as-is without making changes as removing some calls may break unit tests and expectations in regards to spy functions or outcome. There are things that may be deprecated or removed, and stat keys or messaging that may be candidates to update.

## Decision

Finish our module migration then continue development once it is in a stable form. Finish the changes then determine if there should be a follow up PR to adjust folder structure and namespace.

## Consequences

Our initial flip over will be smaller but it will be impactful and pave the road for future conversations about the best way to migrate parts of the module and how it will work.
