# 4. Saved Claims and Sidekiq Jobs

Date: 2024-07-10

## Status

Accepted

## Context

If we are to adapt the `SubmitBenefitsIntakeClaim` job then we must include our own `saved_claim` class that points to the new job. The code for this override can be found in `modules/pensions/app/models/pensions/saved_claim.rb`. This presents an issue with the `inheritance_column` possibly changing since our underlying model is technically a different class.

Similarly in the `SavedClaim::Pension` class under the `modules/pensions/app/models/pensions/saved_claim/pension.rb`, if we are to adapt the `Pensions::BenefitsIntake::SubmitClaimJob` code to the module we must change this job type. Since we are inheriting off of the new `SavedClaim` from the module, we must also be somewhat concerned about how the `inheritance_column` would change any SQL queries when selecting 'types'.

The `Pensions::BenefitsIntake::SubmitClaimJob` brings along some service and metadata classes as direct dependencies. We are currently proxying these classes.

It also references the claim class, which we are swapping in the module. It uses the monitoring classes `Pension21p527ez::Monitor` which we are copying into our module folder.

## Decision

We did not want to adopt this job for now and we have decided to keep a copy of this code in our module in tandem with the existing code in the root project.

## Consequences

We will do as little stubbing as possible and instead take the shortest path when it comes to migrating over the ownership of the files. We will think about how inheritance could impact the software.
