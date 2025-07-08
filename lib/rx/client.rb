# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'rx/configuration'
require 'rx/client_session'
require 'rx/rx_gateway_timeout'
require 'active_support/core_ext/hash/slice'
require 'vets/collection'

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

    def initialize(session:, upstream_request: nil)
      @upstream_request = upstream_request
      super(session:)
    end

    def request(method, path, params = {}, headers = {}, options = {})
      super(method, path, params, headers, options)
    rescue Common::Exceptions::GatewayTimeout
      raise Rx::RxGatewayTimeout
    end

    ##
    # Get a list of active Prescriptions using new model PrescriptionDetails
    #
    # @return [Common::Collection[PrescriptionDetails]]
    #
    def get_active_rxs_with_details
      cache_key = cache_key('getactiverx')
      data = ::PrescriptionDetails.get_cached(cache_key)
      if data
        Rails.logger.info("rx PrescriptionDetails cache fetch with cache_key: #{cache_key}")
        statsd_cache_hit
        Vets::Collection.new(data, ::PrescriptionDetails)
      else
        Rails.logger.info("rx PrescriptionDetails service fetch with cache_key: #{cache_key}")
        statsd_cache_miss
        result = perform(:get, get_path('getactiverx'), nil, get_headers(token_headers)).body
        collection = Vets::Collection.new(
          result[:data],
          ::PrescriptionDetails,
          metadata: result[:metadata],
          errors: result[:errors]
        )
        ::PrescriptionDetails.set_cached(cache_key, result[:data]) if cache_key && result[:data]
        collection
      end
    end

    ##
    # Get a list of all Prescriptions
    # @return [Common::Collection[PrescriptionDetails]]
    #
    def get_all_rxs
      cache_key = cache_key('medications')
      data = PrescriptionDetails.get_cached(cache_key)
      if data
        Rails.logger.info("rx PrescriptionDetails cache fetch with cache_key: #{cache_key}")
        statsd_cache_hit
        Vets::Collection.new(data, PrescriptionDetails)
      else
        Rails.logger.info("rx PrescriptionDetails service fetch with cache_key: #{cache_key}")
        statsd_cache_miss
        result = perform(:get, get_path('medications'), nil, get_headers(token_headers)).body
        collection = Vets::Collection.new(
          result[:data],
          PrescriptionDetails,
          metadata: result[:metadata],
          errors: result[:errors]
        )
        PrescriptionDetails.set_cached(cache_key, result[:data]) if cache_key && result[:data]
        collection
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
    def get_rx_details(id)
      collection = get_all_rxs
      collection.find_by('prescription_id' => { 'eq' => id })
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
      Tracking.new(data.merge(metadata: json[:metadata]))
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
      json = json.merge(data: tracking_history)
      Vets::Collection.new(json[:data], Tracking, metadata: json[:metadata], errors: json[:errors])
    end

    ##
    # Post a list of Prescription refills
    #
    # @param ids [Array] an array of Rx ids
    # @return [Faraday::Env]
    #
    def post_refill_rxs(ids)
      if (result = perform(:post, get_path('rxrefill'), ids, get_headers(token_headers)))
        Rails.logger.info('Clearing PrescriptionDetails and Vets::Collection caches',
                          cache_keys: [cache_key('medications'), cache_key('getactiverx')].compact)
        ::PrescriptionDetails.clear_cache(cache_key('medications')) if cache_key('medications')
        ::PrescriptionDetails.clear_cache(cache_key('getactiverx')) if cache_key('getactiverx')
        Vets::Collection.bust([cache_key('medications'), cache_key('getactiverx')].compact)
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
        Rails.logger.info('Clearing PrescriptionDetails and Vets::Collection caches',
                          cache_keys: [cache_key('medications'), cache_key('getactiverx')].compact)
        ::PrescriptionDetails.clear_cache(cache_key('medications')) if cache_key('medications')
        ::PrescriptionDetails.clear_cache(cache_key('getactiverx')) if cache_key('getactiverx')
        Vets::Collection.bust([cache_key('medications'), cache_key('getactiverx')].compact)
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
      env = if Flipper.enabled?(:mhv_medications_migrate_to_api_gateway)
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
      get_headers(headers)
    end

    def get_headers(headers)
      headers = headers.dup
      if Flipper.enabled?(:mhv_medications_migrate_to_api_gateway)
        headers.merge('x-api-key' => config.x_api_key)
      else
        headers
      end
    end

    def get_path(endpoint)
      base_path = Flipper.enabled?(:mhv_medications_migrate_to_api_gateway) ? 'pharmacy/ess' : 'prescription'
      "#{base_path}/#{endpoint}"
    end

    def get_preferences_path(endpoint)
      base_path = if Flipper.enabled?(:mhv_medications_migrate_to_api_gateway)
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

    def statsd_cache_hit
      StatsD.increment('api.rx.cache.hit')
    end

    def statsd_cache_miss
      StatsD.increment('api.rx.cache.miss')
    end
  end
end
