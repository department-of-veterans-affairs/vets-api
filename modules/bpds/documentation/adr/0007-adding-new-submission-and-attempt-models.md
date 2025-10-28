# 7. Adding new submission and attempt models with data encryption

Date: 2025-05-01

## Status

Accepted

## Context

With the new submissions and attempts tables added to the database schema, we now need a data entity layer to be able to interact with these tables. Model classes for each type of submission and attempt tables would be used to define encryption on specific data fields and house any specific logic pertaining to each type.

## Decision

We decided to use abstract classes for the generic Submissions and SubmissionAttempts classes and define concrete versions of them for each type. The abstract classes would house any common validations or callbacks all Submissions and SubmissionAttempts would share, and the concrete classes would extend this behavior and implement any specialized logic or class associations.

## Consequences

This use of abstract classes and inheritance should serve to keep our code DRY and easily extendable with new Submission and SubmissionAttempt types in the future.
