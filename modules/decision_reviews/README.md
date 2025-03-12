# DecisionReviews

Decision Reviews covers three forms that allow veterans to request additional review of a VA benefits decision:
Supplemental Claim (20-0995)
Higher Level Review (20-0996)
Notice of Disagreement (10182)

This engine is an effort to isolate all the code in `vets-api` relating to these three forms.
Note: "plugin" and "engine" are somewhat interchangeable terms in this context.

## Why an Engine?

The `vets-api` code repository is large and complex, and many different teams make changes every day. While teams work to keep their code contained and minimize impact on other teams, there are no hard barriers to prevent code sharing or unintended side effects. Automated tests can catch a lot of errors, but they are also not a guarantee against side effects. Overall, this situation increases cognitive overhead for engineers, and it requires additional caution during code review, both of which can slow down delivery.

The Ruby on Rails framework has a concept called an Engine that acts as a “one way mirror”. Code outside the Engine cannot reference or “see” code inside the Engine, but code inside the Engine can still use shared code in the main Rails application, and rely on the deployment infrastructure for the main application. This structure provides framework-level guarantees that changes to Engine code cannot affect code in the main Rails application.

## Usage

Add the plugin to your Gemfile and mount the engine in your `routes.rb` file. This will give you access to all the necessary endpoints and Sidekiq job classes.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "decision_reviews"
```

And then execute:

```bash
$ bundle
```

```ruby
mount DecisionReviews::Engine, at: '/decision_reviews'
```

## Transition Plan

This kind of architecture change is best handled in multiple steps, with a simple, fast rollback strategy for each step. This approach requires some amount of duplicated code and effort during the transition, but is more resilient than “move fast and break things”. Ideally, no other code changes would be made while this plan is in-progress, so duplication shouldn’t be a problem.

Decision Reviews code in vets-api can be roughly broken down into:
Background Jobs
Controllers and Routes
Primary Utilities (helper classes that are shared across multiple other classes)
Secondary Utilities (classes that are included by other utility classes but never directly included in non-utility classes) 
Models

Each of these categories includes tests

### COMPLETE - Phase 1: Duplicate Background Jobs and Primary Utilities

Create copies of all our background jobs inside the engine, including tests. Create copies of any primary utilities in the engine, but allow them to reference secondary utilities that stay in the main application. Any model references should point to original models in the main application. Mount the engine in the main application (it should not do anything).

Risks:

- If changes need to be made to a job, they will need to be made and tested in two places.

Mitigation:

- Code freeze, except for urgent bugs: Background jobs and Utilities

### COMPLETE - Phase 2: Transition to Engine Scheduled Background Jobs

Update the schedule file to ALSO reference the engine version of each job. All these jobs are idempotent (can be run multiple times with no overlapping effects) so this should be safe. Exclude any jobs that are not scheduled (form4142_submit and submit_upload), they are not safe to run multiple times.

Risks:

- If changes need to be made to a job, they will need to be made and tested in two places.
- If something about the engine configuration is wrong in a way that tests don’t show, this is the first time we will know it

Mitigation:

- Code freeze, except for urgent bugs: Background jobs and Utilities
- The old jobs will still be running, so no functionality will be lost if the new jobs run into errors

### COMPLETE Phase 3: Delete Old Background Jobs

Remove the old job classes from the schedule file. Add logging to those old classes so we know right away if anyone else is calling them somehow. After 2 weeks with no calls to the old job code, delete it.

Risks:

- Until actual deletion, if changes need to be made to a job, they will need to be made and tested in two places.

Mitigation:

- Code freeze, except for urgent bugs: Background jobs and Utilities

### COMPLETE - Phase 4: Duplicate Controllers and Necessary Utilities

Duplicate all controllers, tests, and any primary utilities they reference. Allow them to reference secondary utilities that stay in the main application. Any model references should point to original models in the main application. Add routes to the engine that preserve the original routes but namespace them to the engine.

Frontend: Add flipper toggles to use the new routing, but do not turn them on.

Risks:

- If changes need to be made to a controller, they will need to be made and tested in two places.
- The routes will be publicly available, so theoretically someone else on the frontend could call them

Mitigation:

- Code freeze, except for urgent bugs: Controllers, routes, and Utilities
- Not a significant concern.

### COMPLETE Phase 5: Transition to Engine Controllers

Toggle the routes on the frontend to point to the engine routes/controllers. Leave the old routes and controllers in place, but add logging so we are alerted if anyone else is calling them. Keep an eye on traffic and form creation numbers to make sure behavior seems consistent.

Risks:

- If changes need to be made to a controller, they will need to be made and tested in two places.
- The old routes will be publicly available, so theoretically someone else on the frontend could call them

Mitigation:

- Code freeze, except for urgent bugs: Controllers, routes, and Utilities
- Logging and alerts

### COMPLETE Phase 6: Delete Old Controllers and Utilities

Delete old routes, controllers, and any primary utilities in the main app that are no longer used. At this point the change should be invisible to the system.

### IN PROGRESS Phase 7: Migrate Existing Secondary Utilities to Engine

Any secondary utilities that belong to the DR team and are not being referenced by any DR code in the main app should be migrated to the engine. Go slow, search for references, run all the tests, announce it in shared channels.

Work with any teams that were relying on our code to disentangle, OR agree this is shared behavior that should be owned by the platform team and live in the main app.

Risks:

- If someone else is using our code in surprising ways, this could break their features
- If we don’t know what other code it might be, manual testing is guess and check

Mitigation:

- Automated testing, manual testing in Staging

### FUTURE WORK Phase 8: Migrate Models to Engine

Update 2/25: Current team assessment is that this work would be more effort than warranted for the current benefit. If we move to a separate repo at some point we will revisit this work.

Models are more complex to move, because models have representations in the database, and the expected name of a model table in the database changes when the model is moved to an engine, even though the engine and main app share the same database. I think we can migrate our models, possibly without changes to the database, but it will require more customization of the engine than we have done to this point.

Duplicate one model in the engine, and override the expected DB name. Can this model and the original model in the main app coexist without collision? If yes, try keeping both around for a while, and only using the engine version in 1 place in the code. 
Slowly transition all references to the engine version. 
If this is successful, repeat the process for all our models

We don’t have a working proof of concept for this step (which we do for all the other steps) so risks and mitigations need more investigation.

### IN PROGRESS Phase 9 (tentative): Remove Dependencies on Shared Code

Some decision review code does rely on other classes written and maintained by the platform team in the main app. How much of this truly needs to be shared? This is a longer conversation the team can have once we see how far we can get by isolating our own code. Other teams (Pensions) have for now made the choice to rely on the shared SavedClaim model, for example, instead of trying to create their own version. Some amount of shared behavior is probably healthy given this is a single application that should behave consistently. How much?

Risks:

- If changes need to be made to a job, they will need to be made and tested in two places.
- If something about the engine configuration is wrong in a way that tests don’t show, this is the first time we will know it

Mitigation:

- Code freeze, except for urgent bugs: Background jobs and Utilities
- The old jobs will still be running, so no functionality will be lost if the new jobs run into errors
