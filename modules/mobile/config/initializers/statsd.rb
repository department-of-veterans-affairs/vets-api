# frozen_string_literal: true

StatsD.logger = Logger.new 'log/statsd.log' if Rails.env.development?

Rails.application.reloader.to_prepare do
  # Authentication #-------------------------------------------------------------

  # meta binding
  Mobile::ApplicationController.extend StatsD::Instrument
  Mobile::ApplicationController.statsd_count_success :authenticate,
                                                     'mobile.authentication'

  # Payment Information #--------------------------------------------------------

  Mobile::V0::PaymentInformation::Proxy.extend StatsD::Instrument
  Mobile::V0::PaymentInformation::Proxy.statsd_count_success :get_payment_information,
                                                             'mobile.payment_information.get_payment_information'
  Mobile::V0::PaymentInformation::Proxy.statsd_count_success :update_payment_information,
                                                             'mobile.payment_information.update_payment_information'

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

  # Payment History #------------------------------------------------------------
  Mobile::V0::PaymentHistoryController.extend StatsD::Instrument
  Mobile::V0::PaymentHistoryController.statsd_count_success :index, 'mobile.payment_history.index'
end
