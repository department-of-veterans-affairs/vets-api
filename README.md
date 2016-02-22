# Roadrunner Rails
[![Build Status](https://travis-ci.org/department-of-veterans-affairs/roadrunner-rails.svg?branch=master)](https://travis-ci.org/department-of-veterans-affairs/roadrunner-rails)

Roadrunner Rails is a template for new Rails projects for the VA. It's pre-customized to work within the VA ecosystem.

```                               
      qWWWgaap                    
]W#########WW##Z##LaQbp           
   ]"?!??QW#ZZ#######m#b          
       )Wm####Z####Z###b          
                )????mm###a
                       ]####? p
                       y?Y?Y(   p
                       w####ZcL]T___$
                         ^<iQrcZZZr-'
                          :klf
p                          ]i                                    _
3p                         ]lp               _ __ ___   __ _  __| |_ __ _   _ _ __  _ __   ___ _ __
llLp                       ]If       ------ | '__/ _ \ / _` |/ _` | '__| | | | '_ \| '_ \ / _ \ '__|
zIl3q.                     ]If   __________ | | | (_) | (_| | (_| | |  | |_| | | | | | | |  __/ |
"gwzI3q                    kd          ____ |_|  \___/ \__,_|\__,_|_|   \__,_|_| |_|_| |_|\___|_|
   )?^y3qp               qJIf                                                     _ __ __ _(_) |___
      J4wwLagagagWWWWWhwilld                                     ______________  | '__/ _` | | / __|
         ?!4m#m####ZZ#Zmlllf               p           ------------------------  | | | (_| | | \__ \
      gKX@CiillTYXmDYYTlllmp         aggQ"4XXLga               ________________  |_|  \__,_|_|_|___/
    aGZF????????    )?4@illf   aggJQ"!'=jg#?':?"4#Lgga
  aAq"'.                "wuRXXXm!?     ]X#Xp      J!mX#XZZXUa
aAm?                     )!"!'.         !pXP           !XXZXXQ
r'                                                      )4XXWW
.
```

## Ruby Setup
In order to use Roadrunner Rails, you'll need Ruby installed, and either rvm or rbenv to manage your Ruby versions.
If you don't, follow the directions below:

Install rbenv, which is a tool that helps install/manage versions of Ruby (Note: make sure and follow the brew's post-install instructions):

```
$ brew install rbenv
```

And follow the initialization instructions for rbenv, provided by brew

```
$ rbenv init
```

Using rbenv install ruby:

```
$ rbenv install 2.3.0
```

## Creating a New Roadrunner Project
First, clone the `roadrunner-rails` repository into a new folder with your project name.
Seperate words in the folder name using hyphens (example: `my-new-project`).

```
$ git clone https://github.com/department-of-veterans-affairs/roadrunner-rails my-new-project
```

Then run the setup script,

```
$ cd my-new-project
$ ./bin/setup
```

You'll need to have `phantomjs` installed to run the feature specs. If you have homebrew, it's as easy as:

```
$ brew install phantomjs
```

If not, follow installation instructions on [their website](http://phantomjs.org/).

After that, you should be ready to roll! Use any of the Rails commands (like `rails s`) or try some of the commands below.

Beep, beep!

## Commands
- `bundle exec rake lint` - Run the full suite of linters on the codebase.
- `bundle exec guard` - Runs the guard test server that reruns your tests after files are saved. Useful for TDD!
- `bundle exec rake security` - Run the suite of security scanners on the codebase.
- `bundle exec rake ci` - Run all build steps performed in Travis CI.

## Gems
Roadrunner Rails adds some additional gems for making Rails development better.

### Testing
- [RSpec](https://github.com/rspec/rspec) - Ruby testing framework for readable BDD tests.
- [RSpec Rails](https://github.com/rspec/rspec-rails) - Rails helpers for rSpec.
- [Guard](https://github.com/guard/guard) - Testing server for better TDD flow.
- [Capybara](https://github.com/jnicklas/capybara) - DSL for easily writing automated feature tests.
- [Sniffybara](https://github.com/department-of-veterans-affairs/sniffybara) - Custom Poltergeist (PhantomJS) driver for Capybara that checks for accessibility defects in your feature tests.

### Linting
- [Rubocop](https://github.com/bbatsov/rubocop) for Ruby style linting.
- [scss-lint](https://github.com/brigade/scss-lint) configured with [18F's CSS coding styleguide](https://pages.18f.gov/frontend/css-coding-styleguide/).
- [jshint](https://github.com/damian/jshint) for Javascript.

### Security
- [Breakman](https://github.com/presidentbeef/brakeman) for Rails static code analysis for secuirty vulnerabilities
- [bundler-audit](https://github.com/rubysec/bundler-audit) for checking known security vunerabilities of gems.
