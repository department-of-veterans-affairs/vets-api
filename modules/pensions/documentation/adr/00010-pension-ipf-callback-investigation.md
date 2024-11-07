# 10. Investigation of Pension IPF Callbacks

Date: 2024-11-07

## Status

N/A

## Context

Our team recently came across this callback in `config/routes.rb` as `pension_ipf_callbacks`, accompanying flipper 
and `controller app/controllers/v1/pension_ipf_callbacks_controller.rb`. This ADR is to figure out if we still need it or not.

## Decision



## Consequences

After running the migration script and swapping the encryption context of the models, we should be able to have both models access the encrypted data from all periods.
