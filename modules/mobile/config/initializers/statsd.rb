# frozen_string_literal: true

# add metrics via statsd metaprogramming methods https://github.com/Shopify/statsd-instrument#metaprogramming-methods
# and set initial values for increments to 0 (does not reset values, ensures counts carry over server instances)
# statsd_count_success automatically appends .success or .failure

# Meta binding
Mobile::ApplicationController.extend StatsD::Instrument
Mobile::ApplicationController.statsd_count_success :authenticate,
                                                   'mobile.authentication'

Mobile::V0::Appointments::Proxy.extend StatsD::Instrument
Mobile::V0::Appointments::Proxy.statsd_count_success :get_appointments,
                                                     'mobile.appointments.get_appointments'
Mobile::V0::Appointments::Proxy.statsd_count_success :put_cancel_appointment,
                                                     'mobile.appointments.put_cancel_appointment'

Mobile::V0::PaymentInformation::Proxy.extend StatsD::Instrument
Mobile::V0::PaymentInformation::Proxy.statsd_count_success :get_payment_information,
                                                           'mobile.payment_information.get_payment_information'
Mobile::V0::PaymentInformation::Proxy.statsd_count_success :update_payment_information,
                                                           'mobile.payment_information.update_payment_information'

# Authentication

# failure rate for authentication
StatsD.increment('mobile.authentication.success', 0)
StatsD.increment('mobile.authentication.failure', 0)

# Appointments

# service failure rate for the appointments list
StatsD.increment('mobile.appointments.get_appointments.success', 0)
StatsD.increment('mobile.appointments.get_appointments.failure', 0)

# service failure rate for cancelling appointments
StatsD.increment('mobile.appointments.put_cancel_appointment.success', 0)
StatsD.increment('mobile.appointments.put_cancel_appointment.failure', 0)

# which facilities most often appear in the list (tags:["facility_id:#{facility_id}"])
StatsD.increment('mobile.appointments.facilities', 0)
# which appointment types most often appear in the list (tags:["type:#{type}"])
StatsD.increment('mobile.appointments.type', 0)

# Letters

# which letters are most often downloaded
StatsD.increment('mobile.letters.download.type', 0)

# Claims and Appeals

# which claim types are most often viewed
StatsD.increment('mobile.claims_and_appeals.claim.type', 0)

# Payment Information

# service failure rate for getting payment information
StatsD.increment('mobile.payment_information.get_payment_information.success', 0)
StatsD.increment('mobile.payment_information.get_payment_information.failure', 0)

# service failure rate for updating payment information
StatsD.increment('mobile.payment_information.update_payment_information.success', 0)
StatsD.increment('mobile.payment_information.update_payment_information.failure', 0)
