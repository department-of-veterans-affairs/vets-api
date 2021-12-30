# frozen_string_literal: true

# add metrics via statsd metaprogramming methods https://github.com/Shopify/statsd-instrument#metaprogramming-methods
# and set initial values for increments to 0 (does not reset values, ensures counts carry over server instances)
# statsd_count_success automatically appends .success or .failure
# rubocop: disable Metrics/BlockLength

StatsD.logger = Logger.new 'log/statsd.log' if Rails.env.development?

Rails.application.reloader.to_prepare do
  # Authentication #-------------------------------------------------------------

  # meta binding
  Mobile::ApplicationController.extend StatsD::Instrument
  Mobile::ApplicationController.statsd_count_success :authenticate,
                                                     'mobile.authentication'

  # failure rate for authentication
  StatsD.increment('mobile.authentication.success', 0)
  StatsD.increment('mobile.authentication.failure', 0)

  # Appointments #---------------------------------------------------------------

  # meta binding
  Mobile::V0::Appointments::Proxy.extend StatsD::Instrument
  Mobile::V0::Appointments::Proxy.statsd_count_success :get_appointments,
                                                       'mobile.appointments.get_appointments'
  Mobile::V0::Appointments::Proxy.statsd_measure :get_appointments,
                                                 'mobile.appointments.get_appointments.measure'
  Mobile::V0::Appointments::Proxy.statsd_count_success :put_cancel_appointment,
                                                       'mobile.appointments.put_cancel_appointment'

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

  # Letters #--------------------------------------------------------------------

  # which letters are most often downloaded
  StatsD.increment('mobile.letters.download.type', 0)

  # Claims and Appeals #---------------------------------------------------------

  # which claim types are most often viewed
  StatsD.increment('mobile.claims_and_appeals.claim.type', 0)

  # Payment Information #--------------------------------------------------------

  Mobile::V0::PaymentInformation::Proxy.extend StatsD::Instrument
  Mobile::V0::PaymentInformation::Proxy.statsd_count_success :get_payment_information,
                                                             'mobile.payment_information.get_payment_information'
  Mobile::V0::PaymentInformation::Proxy.statsd_count_success :update_payment_information,
                                                             'mobile.payment_information.update_payment_information'

  # service failure rate for getting payment information
  StatsD.increment('mobile.payment_information.get_payment_information.success', 0)
  StatsD.increment('mobile.payment_information.get_payment_information.failure', 0)

  # service failure rate for updating payment information
  StatsD.increment('mobile.payment_information.update_payment_information.success', 0)
  StatsD.increment('mobile.payment_information.update_payment_information.failure', 0)

  # Profile updates #------------------------------------------------------------

  Mobile::V0::Profile::SyncUpdateService.extend StatsD::Instrument
  Mobile::V0::Profile::SyncUpdateService.statsd_count_success :save_and_await_response,
                                                              'mobile.profile.update'
  Mobile::V0::Profile::SyncUpdateService.statsd_measure :save_and_await_response,
                                                        'mobile.profile.update.measure'
  Mobile::V0::Profile::SyncUpdateService.statsd_count_success :await_vet360_account_link,
                                                              'mobile.profile.link_account'
  Mobile::V0::Profile::SyncUpdateService.statsd_measure :save_and_await_response,
                                                        'mobile.profile.link_account.measure'

  # service failure rate for updating profile information
  StatsD.increment('mobile.profile.update.success', 0)
  StatsD.increment('mobile.profile.update.failure', 0)

  # which profile data types are most often updated (tags:["type:#{type}"])
  StatsD.increment('mobile.profile.update.type', 0)

  # service failure rate for linking Vet360 accounts (generating an id)
  StatsD.increment('mobile.profile.link_account.success', 0)
  StatsD.increment('mobile.profile.link_account.failure', 0)

  # Push Notifications #------------------------------------------------------------
  Mobile::V0::PushNotificationsController.extend StatsD::Instrument
  Mobile::V0::PushNotificationsController.statsd_count_success :register,
                                                               'mobile.push.registration'
  Mobile::V0::PushNotificationsController.statsd_count_success :get_prefs,
                                                               'mobile.push.get_prefs'
  Mobile::V0::PushNotificationsController.statsd_count_success :set_pref,
                                                               'mobile.push.set_pref'
  Mobile::V0::PushNotificationsController.statsd_count_success :send_notification,
                                                               'mobile.push.send_notification'

  StatsD.increment('mobile.push.registration.success', 0)
  StatsD.increment('mobile.push.registration.failure', 0)

  StatsD.increment('mobile.push.get_prefs.success', 0)
  StatsD.increment('mobile.push.get_prefs.failure', 0)

  StatsD.increment('mobile.push.set_pref.success', 0)
  StatsD.increment('mobile.push.set_pref.failure', 0)

  StatsD.increment('mobile.push.send_notification.success', 0)
  StatsD.increment('mobile.push.send_notification.failure', 0)

  # Secure messaging #------------------------------------------------------------

  # SM cache hit ratio
  StatsD.increment('mobile.sm.cache.hit', 0)
  StatsD.increment('mobile.sm.cache.miss', 0)

  # CDC Vaccine Background Job #--------------------------------------------------
  StatsD.increment('mobile.vaccine_updater_job.success', 0)
  StatsD.increment('mobile.vaccine_updater_job.failure', 0)

  # Immunizations #------------------------------------------------------------
  StatsD.increment('mobile.immunizations.cvx_code_missing', 0)
  StatsD.increment('mobile.immunizations.date_missing', 0)
  # rubocop: enable Metrics/BlockLength
end
