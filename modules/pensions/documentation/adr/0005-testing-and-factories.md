# 5. Testing and Factories

Date: 2024-07-10

## Status

Accepted

## Context
`modules/pensions/spec/models/saved_claim/pension_spec.rb` is the test file for our Pension saved claim. Interesting enough it references some PensionBurial code. When the factories are used, they are designed to create a specific class type. Bringing in this pension spec, requires us to also create new module specific factories.

```rb
  let(:instance) { build(:pensions_saved_claim) }
```
We see that burial attachments are referenced here, perhaps these are supposed to just be attachment files upstream or we copied some technical debt.
```rb
    let!(:attachment1) { create(:pension_burial) }
    let!(:attachment2) { create(:pension_burial) }
```

`modules/pensions/spec/support/saved_claims_spec_helper.rb` has been copied over and we have removed one line from the tests.
```rb
      # reading about inheritance_column and also even then this is not a great test because
      # the type would be different than the class string

      # expect(subject.type).to eq(described_class.to_s)
```
This is because of the `inheritance_column` and the type and the class diverging.

There are also class references to the modules in here that may need to change around depending on if we decide to keep things in the module or reference the root structure.

`modules/pensions/spec/sidekiq/pensions/lighthouse/pension_benefit_intake_job_spec.rb` references a lot of the models that we outlined, it also uses the new factories. It also has some self-references. It also references outside modules like `Datadog` and `Statsd`.

## Decision

We need to maintain another factory for our new module class of this type, we've appended `pensions_module_` as a prefix to this factory. We should use the existing attachment factory from the root project for this and remove any of the extra fixtures that it brings in. We need this new spec helper file to be included in the module and to adjust the tests. We want to support the changes that include the models we are bringing over and nothing else.

## Consequences

We decided that because the pension burial attachment was being used as-is, it may allude to some other refactoring needed. Support this in the best way possible. We might want to create some tests to check the sql is the same as before. Support the code as-is. Review the tests and ensure they are working as intended.
