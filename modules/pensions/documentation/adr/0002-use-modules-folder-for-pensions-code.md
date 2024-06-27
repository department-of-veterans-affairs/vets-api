# 2. Move pensions application to modules folder

Date: 2024-06-18

## Status

Accepted

## Context

The vets-api is a large monorepo with many overlapping forms.  The tangle of code between applications has made it difficult for teams to iterate without impacting others.   

## Decision

In an effort to isolate code, the pensions team has decided to take advantage of [Ruby on Rails Engines](https://guides.rubyonrails.org/engines.html) to create a separate application for the 21P-527 EZ form (pensions).  Engines can be isolated from their host applications which will allow for us to:

- Isolate the code pertinent to Pension
- Work toward running a CI/CD that can be applied only to Pension code

## Consequences

The result of this change will allow for the pensions team to more quickly iterate and innovate on future changes.   There is a risk that isolating pension code will result in a lot of duplication of code.  The longer term goal would be to move common benefits logic into a module of its own as is being done for pension code.
