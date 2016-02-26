# Application Name [![Build Status](https://travis-ci.org/department-of-veterans-affairs/roadrunner-rails.svg?branch=master)](https://travis-ci.org/department-of-veterans-affairs/roadrunner-rails)

Description of your what your project does.

## Developer Setup

1. Install Ruby 2.3. (It is suggested to use a Ruby version manager such as [rbenv](https://github.com/rbenv/rbenv#installation) and then to [install Ruby 2.3](https://github.com/rbenv/rbenv#installing-ruby-versions)).
1. Install Bundler to manager dependencies: `gem install bundler`
1. Setup the database: `bundle exec rake db:migrate`
1. Start the application: `bundle exec rails s`

## Commands
- `bundle exec rake lint` - Run the full suite of linters on the codebase.
- `bundle exec guard` - Runs the guard test server that reruns your tests after files are saved. Useful for TDD!
- `bundle exec rake security` - Run the suite of security scanners on the codebase.
- `bundle exec rake ci` - Run all build steps performed in Travis CI.

## Deployment Instructions

(TODO: Add deployment instructions, Ansible templates when ready.)

## How to Contribute

How do people (internal, external, both) contribute to your project? Do they use something like [GitHub Flow](https://guides.github.com/introduction/flow/)? How do people submit bugs? How do folks submit code patches and features?

**__Suggested Text__**: (take, tweak, or replace)

There are many ways to contribute to this project:

**Bugs**

If you spot a bug, let us know! File a GitHub Issue for this project. When filing an issue add the following:

- Title: Sentence that summaries the bug concisely
- Comment:
    - The environment you experienced the bug (browser, browser version, kind of account any extensions enabled)
    - The exact steps you took that triggered the bug. Steps 1, 2, 3, etc.
    - The expected outcome
    - The actual outcome, including screen shot
    - (Bonus Points:) Animated GIF or video of the bug occurring
- Label: Apply the label `bug`

**Code Submissions**

This project logs all work needed and work being actively worked on via GitHub Issues. Submissions related to these are especially appreciated, but patches and additions outside of these are also great.

If you are working on something related to an existing GitHub Issue that already has an assignee, talk with them first (we don't want to waste your time). If there is no assignee, assign yourself (if you have permissions) or post a comment stating that you're working on it.

To work on your code submission, follow [GitHub Flow](https://guides.github.com/introduction/flow/):

1. Branch or Fork
1. Commit changes
1. Submit Pull Request
1. Discuss via Pull Request
1. Pull Request gets approved or denied by core team member

If you're from the community, it may take one to two weeks to review your pull request. Teams work in 1 to 2 week sprints, so they need time to need add it to their time line.

## Contact

How can folks contact you (the maintainers of the project). GitHub Handles, Email, etc?

**__Suggested Text__**: (tweak or replace)

If you have a question or comment about this project, file a GitHub Issue with your question in the Title, any context in the Comment, and add the `question` Label. For general questions, tag or assign to the product owner **NAME** (GitHub Handle: **GITHUB HANDLE**). For design questions, tag or assign to the design lead,  **NAME** (GitHub Handle: **GITHUB HANDLE**). For technical questions, tag or assign to the engineering lead, **NAME** (GitHub Handle: **GITHUB HANDLE**).
