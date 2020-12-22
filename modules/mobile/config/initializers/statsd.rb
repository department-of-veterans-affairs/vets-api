# frozen_string_literal: true

# add metrics via statsd metaprogramming methods https://github.com/Shopify/statsd-instrument#metaprogramming-methods
# and set initial values for increments to 0 (does not reset values, ensures counts carry over server instances)
# statsd_count_success automatically appends .success or .failure

Mobile::ApplicationController.extend StatsD::Instrument
Mobile::ApplicationController.statsd_count_success :authenticate, 'mobile.authentication'
StatsD.increment('mobile.authentication.success', 0)
StatsD.increment('mobile.authentication.failure', 0)

Mobile::V0::Appointments::Service.extend StatsD::Instrument
Mobile::V0::Appointments::Service.statsd_count_success :get_appointments,
                                                       'mobile.appointments.service.get_appointments'

StatsD.increment('mobile.appointments.get_appointments.success', 0)
StatsD.increment('mobile.appointments.get_appointments.failure', 0)
