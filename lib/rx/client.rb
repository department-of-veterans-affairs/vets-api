# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'rx/configuration'
require 'rx/client_session'
require 'rx/rx_gateway_timeout'
require 'active_support/core_ext/hash/slice'

module Rx
  ##
  # Core class responsible for Rx API interface operations
  #
  class Client < Common::Client::Base
    include Common::Client::Concerns::MHVSessionBasedClient

    configuration Rx::Configuration
    client_session Rx::ClientSession

    STATSD_KEY_PREFIX = 'api.mhv.rxrefill'
    CACHE_TTL = 3600 * 1 # 1 hour cache
    CACHE_TTL_ZERO = 0

    def initialize(session:, upstream_request: nil, app_token: nil)
      @upstream_request = upstream_request
      @app_token = app_token || config.app_token if Flipper.enabled?(:mhv_medications_client_test)
      if Flipper.enabled?(:mhv_medications_client_test) && @app_token == config.app_token
        Rails.logger.info('Initializing client for VAHB')
      elsif Flipper.enabled?(:mhv_medications_client_test) && @app_token == config.app_token_va_gov
        Rails.logger.info('Initializing client for VA.gov')
      end
      super(session:)
    end

    def request(method, path, params = {}, headers = {}, options = {})
      super(method, path, params, headers, options)
    rescue Common::Exceptions::GatewayTimeout
      raise Rx::RxGatewayTimeout
    end

    ##
    # Get a list of active Prescriptions
    #
    # @return [Common::Collection[Prescription]]
    #
    def get_active_rxs
      Common::Collection.fetch(::Prescription, cache_key: cache_key('getactiverx'), ttl: CACHE_TTL_ZERO) do
        perform(:get, get_path('getactiverx'), nil, get_headers(token_headers)).body
      end
    end

    ##
    # Get a list of active Prescriptions using new model PrescriptionDetails
    #
    # @return [Common::Collection[PrescriptionDetails]]
    #
    def get_active_rxs_with_details
      Common::Collection.fetch(::PrescriptionDetails, cache_key: cache_key('getactiverx'), ttl: CACHE_TTL) do
        perform(:get, get_path('getactiverx'), nil, get_headers(token_headers)).body
      end
    end

    ##
    # Get a list of all Prescriptions
    #
    # @return [Common::Collection[Prescription]]
    #
    def get_history_rxs
      Common::Collection.fetch(::Prescription, cache_key: cache_key('gethistoryrx'), ttl: CACHE_TTL_ZERO) do
        perform(:get, get_path('gethistoryrx'), nil, get_headers(token_headers)).body
      end
    end

    ##
    # Get a list of all Prescriptions using different api endpoint that returns additional
    # data per rx compared to /gethistoryrx
    #
    # @return [Common::Collection[PrescriptionDetails]]
    #
    def get_all_rxs
      Common::Collection.fetch(::PrescriptionDetails, cache_key: cache_key('medications'), ttl: CACHE_TTL) do
        perform(:get, get_path('medications'), nil, get_headers(token_headers)).body
      end
    end

    ##
    # Get documentation for a single prescription
    #
    # @return [Common::Collection[PrescriptionDocumentation]]
    #
    def get_rx_documentation(ndc)
      perform(:get, get_path("getrxdoc/#{ndc}"), nil, get_headers(token_headers)).body
    end

    ##
    # Get a single Prescription
    #
    # @param id [Fixnum] An Rx id
    # @return [Prescription]
    #
    def get_rx(id)
      collection = get_history_rxs
      collection.find_first_by('prescription_id' => { 'eq' => id })
    end

    ##
    # Get a single Prescription using different api endpoint that returns additional data compared to /gethistoryrx
    #
    # @param id [Fixnum] An Rx id
    # @return [Prescription]
    #
    def get_rx_details(id)
      collection = get_all_rxs
      collection.find_first_by('prescription_id' => { 'eq' => id })
    end

    ##
    # Get tracking for a Prescription
    #
    # @param id [Fixnum] an Rx id
    # @return [Tracking]
    #
    def get_tracking_rx(id)
      json = perform(:get, get_path("rxtracking/#{id}"), nil, get_headers(token_headers)).body
      data = json[:data].first.merge(prescription_id: id)
      Tracking.new(json.merge(data:))
    end

    ##
    # Get a list of tracking history for a Prescription
    #
    # @param id [Fixnum] an Rx id
    # @return [Common::Collection[Tracking]]
    #
    def get_tracking_history_rx(id)
      json = perform(:get, get_path("rxtracking/#{id}"), nil, get_headers(token_headers)).body
      tracking_history = json[:data].map { |t| t.to_h.merge(prescription_id: id) }
      Common::Collection.new(::Tracking, **json.merge(data: tracking_history))
    end

    ##
    # Post a list of Prescription refills
    #
    # @param ids [Array] an array of Rx ids
    # @return [Faraday::Env]
    #
    def post_refill_rxs(ids)
      if (result = perform(:post, get_path('rxrefill'), ids, get_headers(token_headers)))
        increment_refill(ids.size)
      end
      result
    end

    ##
    # Post a Prescription refill
    #
    # @param id [Fixnum] an Rx id
    # @return [Faraday::Env]
    #
    def post_refill_rx(id)
      if (result = perform(:post, get_path("rxrefill/#{id}"), nil, get_headers(token_headers)))
        keys = [cache_key('getactiverx'), cache_key('gethistoryrx')].compact
        Common::Collection.bust(keys) unless keys.empty?
        increment_refill
      end
      result
    end

    ##
    # Get Prescription preferences
    #
    # @todo Might need better error handling around this.
    # @return [PrescriptionPreference]
    #
    def get_preferences
      response = {}
      config.parallel_connection.in_parallel do
        response.merge!(get_notification_email_address)
        response.merge!(rx_flag: get_rx_preference_flag[:flag])
      end
      PrescriptionPreference.new(response)
    end

    ##
    # Set Prescription preferences
    #
    # @note Don't do this one in parallel since you want it to behave like a single atomic operation.
    # @return [PrescriptionPreference]
    # @raise [Common::Exceptions::BackendServiceException] if unhandled validation error is encountered in
    #  email_address, as mapped to RX157 code in config/locales/exceptions.en.yml
    #
    def post_preferences(params)
      mhv_params = PrescriptionPreference.new(params).mhv_params
      post_notification_email_address(mhv_params.slice(:email_address))
      post_rx_preference_flag(mhv_params.slice(:rx_flag))
      get_preferences
    end

    def get_session_tagged
      Sentry.set_tags(error: 'mhv_session')
      env = if Settings.mhv.rx.use_new_api.present? && Settings.mhv.rx.use_new_api
              perform(:get, 'usermgmt/auth/session', nil, auth_headers)
            else
              perform(:get, 'session', nil, auth_headers)
            end
      Sentry.get_current_scope.tags.delete(:error)
      env
    end

    private

    def auth_headers
      headers = get_headers(
        config.base_request_headers.merge(
          'appToken' => config.app_token,
          'mhvCorrelationId' => session.user_id.to_s
        )
      )
      headers['appToken'] = @app_token if Flipper.enabled?(:mhv_medications_client_test)
      get_headers(headers)
    end

    def get_headers(headers)
      headers = headers.dup
      if Settings.mhv.rx.use_new_api.present? && Settings.mhv.rx.use_new_api
        api_key = @app_token == config.app_token_va_gov ? Settings.mhv.rx.x_api_key : Settings.mhv_mobile.x_api_key
        headers.merge('x-api-key' => api_key)
      else
        headers
      end
    end

    def get_path(endpoint)
      base_path = Settings.mhv.rx.use_new_api.present? && Settings.mhv.rx.use_new_api ? 'pharmacy/ess' : 'prescription'
      "#{base_path}/#{endpoint}"
    end

    def get_preferences_path(endpoint)
      base_path = if Settings.mhv.rx.use_new_api.present? && Settings.mhv.rx.use_new_api
                    'usermgmt/notification'
                  else
                    'preferences'
                  end
      "#{base_path}/#{endpoint}"
    end

    def cache_key(action)
      return nil unless config.caching_enabled?
      return nil if session.user_id.blank?

      "#{session.user_id}:#{action}"
    end

    def increment_refill(count = 1)
      tags = []
      tags.append("source_app:#{@upstream_request.env['SOURCE_APP']}") if @upstream_request
      StatsD.increment("#{STATSD_KEY_PREFIX}.refills.requested", count, tags:)
    end

    # NOTE: After June 17, MHV will roll out an improvement that collapses these
    # into a single endpoint so that you do not need to make multiple distinct
    # requests. They will keep these around for some time and eventually deprecate.

    # Current Email Account that receives notifications
    def get_notification_email_address
      config.parallel_connection.get(get_preferences_path('email'), nil, get_headers(token_headers)).body
    end

    # Current Rx preference setting
    def get_rx_preference_flag
      config.parallel_connection.get(get_preferences_path('rx'), nil, get_headers(token_headers)).body
    end

    # Change Email Account that receives notifications
    def post_notification_email_address(params)
      config.parallel_connection.post(get_preferences_path('email'), params, get_headers(token_headers))
    end

    # Change Rx preference setting
    def post_rx_preference_flag(params)
      params = { flag: params[:rx_flag] }
      config.parallel_connection.post(get_preferences_path('rx'), params, get_headers(token_headers))
    end
  end
end
