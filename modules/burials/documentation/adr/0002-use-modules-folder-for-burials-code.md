# 2. Move burials application to modules folder

Date: 2024-10-10

## Status

Accepted

## Context

The vets-api is a large monorepo with many overlapping forms.  The tangle of code between applications has made it difficult for teams to iterate without impacting others.   

## Decision

In an effort to isolate code, the PBP team has decided to take advantage of [Ruby on Rails Engines](https://guides.rubyonrails.org/engines.html) to create a separate application for the 21P-530EZ form (burials).  Engines can be isolated from their host applications which will allow for us to:

- Isolate the code pertinent to Burials
- Work toward running a CI/CD that can be applied only to Burial code

## Consequences

The result of this change will allow for the PBP team to more quickly iterate and innovate on future changes.   There is a risk that isolating burial code will result in a lot of duplication of code.  The longer term goal would be to move common benefits logic into a module of its own as is being done for burial code.
