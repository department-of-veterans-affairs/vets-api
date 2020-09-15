# frozen_string_literal: true

# add metrics via statsd metaprogramming methods https://github.com/Shopify/statsd-instrument#metaprogramming-methods
# and set initial values for increments to 0 (does not reset values, ensures counts carry over server instances)
# statsd_count_success automatically appends .success or .failure

Mobile::ApplicationController.extend StatsD::Instrument
Mobile::ApplicationController.statsd_count_success :authenticate, 'mobile.application_controller.authenticate'
StatsD.increment('mobile.application_controller.authenticate.success', 0)
StatsD.increment('mobile.application_controller.authenticate.failure', 0)

Mobile::ApplicationController.statsd_count_success :create_iam_session,
                                                   'mobile.application_controller.create_iam_session'
Mobile::ApplicationController.statsd_measure :create_iam_session,
                                             'mobile.application_controller.create_iam_session.measure'
StatsD.increment('mobile.application_controller.create_iam_session.success', 0)
StatsD.increment('mobile.application_controller.create_iam_session.failure', 0)
StatsD.increment('mobile.application_controller.create_iam_session.inactive_session', 0)
