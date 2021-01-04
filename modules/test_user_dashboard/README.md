# Test User Dashboard
Rails engine module for Test User Dashboard integration.

## Usage
Test User Dashboard workflowys are used through a [standalone frontend application](https://github.com/department-of-veterans-affairs/vsp-test-user-dashboard), check frontend documentation for usage and local installation help. The production instance of the frontend application is hosted behind the SOCKS proxy; you will [need to have access to the SOCKS proxy](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/platform/working-with-vsp/orientation/request-access-to-tools.md#set-up-the-socks-proxy) to use it.

## Installation
Make sure your vets-api Gemfile contains the following line inside its 'modules' path:

```ruby
gem 'test_user_dashboard'
```

And then execute:
```bash
$ bundle
```

## Contributing
Contribution directions go here.

## Contacts
Test User Dashboard is owned by vsp-identity, questions about its development and use should be directed to the [vsp-identity Slack channel](https://dsva.slack.com/archives/CSFV4QTKN).