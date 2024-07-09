# 2. Nodule Design Overview

Date: 2024-07-09

## Status

Accepted

## Overview

### Stub classes

These models are required or used throughout our code and should not be considered as part of the pensions module.

1. modules/pensions/app/models/pensions/form_submission.rb
1. modules/pensions/app/models/pensions/form_submission_attempt.rb
1. modules/pensions/app/models/pensions/in_progress_form.rb
1. modules/pensions/app/models/pensions/persistent_attachment.rb
1. modules/pensions/app/models/pensions/persistent_attachments/pension_burial.rb

**Decision:** We will remove these proxy classes when possible and reference the root folder.
**Next steps:** Remove the proxy classes and document the dependencies instead.

### Saved Claims and Sidekiq Jobs

If we are to adapt the `SubmitBenefitsIntakeClaim` job then we must include our own `saved_claim` class that points to the new job. The code for this override can be found in `modules/pensions/app/models/pensions/saved_claim.rb`. This presents an issue with the `inheritance_column` possibly changing since our underlying model is technically a different class.

**Next steps:** Decide if we will bring this job over to the module for now or remove it.
**Decision:**

Similarly in the `SavedClaim::Pension` class under the `modules/pensions/app/models/pensions/saved_claim/pension.rb`, if we are to adapt the `PensionBenefitIntakeJob` code to the module we must change this job type. Since we are inheriting off of the new `SavedClaim` from the module, we must also be somewhat concerned about how the `inheritance_column` would change any SQL queries when selecting 'types'.

**Decision:** We have decided to keep a copy of this code in our module in tandem with the existing code in the root project.
**Next steps:** Ensure that this new class is backwards compatible with the existing class when it comes to model creation and selections.

The `PensionBenefitIntakeJob` brings along some service and metadata classes as direct dependencies. We are currently proxying these classes.

1. modules/pensions/lib/pensions/lighthouse/benefits_intake/service.rb
1. modules/pensions/lib/pensions/lighthouse/benefits_intake/metadata.rb

**Next steps:** Should we proxy these classes or duplicate the code and maintain it in the module?
**Decision:**

It also references the claim class, which we are swapping in the module. It uses the monitoring classes `Pension21p527ez::Monitor` which we are copying into our module folder.

**Decision:** We have decided to point to these new classes inside of the module.
**Next steps:** Review the code and ensure that it works.

There are quite a few other references in this job:

1. CentralMail
1. Datadog
1. Sidekiq
1. Common
1. SentryLogging

These seem entirely okay to leave as-is, it would be nice to be able to identify if these are modules or gems themselves and we can build a gem dependency list based on these uses.

The other models which are referenced are some of the classes listed at the beginning of this document.

1. modules/pensions/app/models/pensions/form_submission.rb
1. modules/pensions/app/models/pensions/form_submission_attempt.rb

**Decision:** We have decided not to use these proxy references and instead opt to continue to reference the main project models.
**Next steps:** Revert the references to use the existing root project models for any of these calls.

### Testing and Factories

`modules/pensions/spec/models/saved_claim/pension_spec.rb` is the test file for our Pension saved claim. Interesting enough it references some PensionBurial code. When the factories are used, they are designed to create a specific class type. Bringing in this pension spec, requires us to also create new module specific factories.

```rb
  let(:instance) { FactoryBot.build(:pensions_module_pension_claim) }
```
**Decision:** We need to maintain another factory for our new module class of this type, we've appended `pensions_module_` as a prefix to this factory.
**Next steps:** Review this code and ensure it is working as intended.

```rb
    let!(:attachment1) { FactoryBot.create(:pensions_module_pension_burial) }
    let!(:attachment2) { FactoryBot.create(:pensions_module_pension_burial) }
```

**Decision:** We should use the existing factory from the root project for this and remove any of the extra code that it brings in.
**Next steps:** Revert these lines and remove any files brought in from the creation of it.

`modules/pensions/spec/support/saved_claims_spec_helper.rb` has been copied over and we have removed one line from the tests.
```rb
      # reading about inheritance_column and also even then this is not a great test because
      # the type would be different than the class string

      # expect(subject.type).to eq(described_class.to_s)
```
This is because of the `inheritance_column` and the type and the class diverging.

There are also class references to the modules in here that may need to change around depending on if we decide to keep things in the module or reference the root structure.

**Decision:** We need this file to be included in the module and to adjust the tests.
**Next steps:** Support this in the best way possible. We might want to create some tests to check the sql is the same as before.

`modules/pensions/spec/sidekiq/pensions/lighthouse/pension_benefit_intake_job_spec.rb` references a lot of the models that we outlined, it also uses the new factories. It also has some self-references. It also references outside modules like `Datadog` and `Statsd`.

**Decision:** We want to support the changes that include the models we are bringing over and nothing else.
**Next steps:** Make thee changes to remove any removable proxy classes.

### Other considerations

We should determine if we want to bring over `swagger`, `db`, or any other pension-specific files and understand how they would function within the context of a rails engine.

**Next steps:** Determine what other files or changes need to be made.
**Decision:** Swagger seems ready to be moved over, but the db files contain their own conversation and approach on technical debt resolutions.

#### The complexity of migrations

When searching the migrations folder for the term `:saved_claims` we will see that some migrations are dependent on other columns and modules. This means that our record keeping is inherently broken for the scaffolding timeline. A practical approach is that we should create new migrations that check for the existing migration record and do a complete reinstall of the table if one is not provided. Increasing complexity and possible limited by the tooling available, If we did not account for a complete reinstall then we should be able to detect the state of the tables and correct the column structure.

Initially we wanted to squash down the namespaces but the nature of rails convention and folder structure does not make this trivial. Combined with challenges of getting tests to pass when moving the files around, we have opted to re-examine these changes as a secondary change.

**Decisions:** Finish the changes then determine if there should be a follow up PR to adjust folder structure and namespace.

We want to maintain the code as-is without making changes as removing some calls may break unit tests and expectations in regards to spy functions or outcome. There are things that may be deprecated or removed, and stat keys or messaging that may be candidates to update.

**Decisions:** Finish our module migration then continue development once it is in a stable form.


#### Pdf filler library

In the main app there is a lib called `pdf_filler` and this contains the information about the form key value data itself. It's monolithic engineering design, presents some challenges to moving these dependent files completely out of that folder and creating an extension to this library.

`lib/pdf_fill/filler.rb` would need to be refactored to support incoming module registrations and break out of the monolithic folder structures.
`lib/pdf_fill/forms/va21p527ez.rb` would be the form key value pair that needs to be registered
`lib/pdf_fill/forms/pdfs/21P-527EZ.pdf` would be the form template that needs to be registered

##### Pdf filler specs

`spec/lib/pdf_fill/forms/va21p527ez_spec.rb` and the associated `fixtures` would need to be migrated over to run. This may not be entirely complex.

**Decisions:** The PDF Filler presents its own set of challenges to bring together as much of these files without changing the core library too much.
**Next steps:** Look into bringing over the files with minimal impact to the rest of the team projects.
