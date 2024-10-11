# frozen_string_literal: true

StatsD.logger = Logger.new 'log/statsd.log' if Rails.env.development?

require 'caseflow/service'
require 'central_mail/service'
require 'evss/service'
require 'gibft/service'
require 'iam_ssoe_oauth/session_manager'
require 'mpi/service'
require 'saml/errors'
require 'saml/responses/base'
require 'saml/user'
require 'stats_d_metric'
require 'search/service'
require 'search_click_tracking/service'
require 'search_gsa/service'
require 'search_typeahead/service'
require 'va_profile/exceptions/parser'
require 'va_profile/service'
require 'va_notify/service'
require 'hca/service'
require 'carma/client/mule_soft_client'

Rails.application.reloader.to_prepare do
  ActiveSupport::Notifications.subscribe('process_action.action_controller') do |_, _, _, _, payload|
    tags = ["controller:#{payload.dig(:params, :controller)}", "action:#{payload.dig(:params, :action)}",
            "status:#{payload[:status]}"]
    StatsD.measure('api.request.db_runtime', payload[:db_runtime].to_i, tags:)
    StatsD.measure('api.request.view_runtime', payload[:view_runtime].to_i, tags:)
  end

  ActiveSupport::Notifications.subscribe(/facilities.ppms./) do |_name, start_time, end_time, _id, payload|
    payload_statuses = ["http_status:#{payload.status}"]
    duration = end_time - start_time

    StatsD.increment('facilities.ppms.response.failures', tags: payload_statuses) unless payload.success?
    StatsD.increment('facilities.ppms.response.total', tags: payload_statuses)

    measurement = case payload[:url].path
                  when /FacilityServiceLocator/
                    'facilities.ppms.facility_service_locator'
                  when /ProviderLocator/
                    'facilities.ppms.provider_locator'
                  when /PlaceOfServiceLocator/
                    'facilities.ppms.place_of_service_locator'
                  when %r{Providers\(\d+\)/ProviderServices}
                    'facilities.ppms.providers.provider_services'
                  when /Providers\(\d+\)/
                    'facilities.ppms.providers'
                  end

    if measurement
      tags = ['facilities.ppms']
      params = Rack::Utils.parse_nested_query payload[:url].query

      if params['radius']
        count =
          case payload.body
          when Hash
            payload.body['value']&.count
          when Array
            payload.body&.count
          else
            0
          end

        tags << "facilities.ppms.radius:#{params['radius']}"
        tags << "facilities.ppms.results:#{count || 0}"
      end

      StatsD.measure(measurement, duration, tags:)
    end
  end

  ActiveSupport::Notifications.subscribe(
    'lighthouse.facilities.request.faraday'
  ) do |_, start_time, end_time, _, payload|
    payload_statuses = ["http_status:#{payload.status}"]
    StatsD.increment('facilities.lighthouse.response.failures', tags: payload_statuses) unless payload.success?
    StatsD.increment('facilities.lighthouse.response.total', tags: payload_statuses)

    duration = end_time - start_time
    StatsD.measure('facilities.lighthouse', duration, tags: ['facilities.lighthouse'])
  end

  ActiveSupport::Notifications.subscribe(
    'lighthouse.facilities.v2.request.faraday'
  ) do |_, start_time, end_time, _, payload|
    payload_statuses = ["http_status:#{payload.status}"]
    StatsD.increment('facilities.lighthouse.v2.response.failures', tags: payload_statuses) unless payload.success?
    StatsD.increment('facilities.lighthouse.v2.response.total', tags: payload_statuses)

    duration = end_time - start_time
    StatsD.measure('facilities.lighthouse.v2', duration, tags: ['facilities.lighthouse'])
  end

  # IAM SSOe session metrics
  StatsD.set('iam_ssoe_oauth.users', 0)

  IAMSSOeOAuth::SessionManager.extend StatsD::Instrument
  IAMSSOeOAuth::SessionManager.statsd_count_success :create_user_session,
                                                    'iam_ssoe_oauth.create_user_session'
  IAMSSOeOAuth::SessionManager.statsd_measure :create_user_session,
                                              'iam_ssoe_oauth.create_user_session.measure'

  # init VEText Push Notifications
  begin
    VEText::Service.extend StatsD::Instrument
    VEText::Service.statsd_count_success :register,
                                         "#{VEText::Service::STATSD_KEY_PREFIX}.register"
    VEText::Service.statsd_count_success :get_preferences,
                                         "#{VEText::Service::STATSD_KEY_PREFIX}.get_prefs"
    VEText::Service.statsd_count_success :set_preference,
                                         "#{VEText::Service::STATSD_KEY_PREFIX}.set_pref"
    VEText::Service.statsd_count_success :send_notification,
                                         "#{VEText::Service::STATSD_KEY_PREFIX}.send_notification"
    VEText::Service.statsd_count_success :app_sid,
                                         "#{VEText::Service::STATSD_KEY_PREFIX}.app_lookup"
  rescue ArgumentError
    # noop
    # if these are already registered, they will throw - see source
    # https://github.com/Shopify/statsd-instrument/blob/3c9bf8675e97d98ebeb778a146168cc940b2fc8d/lib/statsd/instrument.rb#L262
  end
end
