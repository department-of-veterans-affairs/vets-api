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

    CACHE_TTL = 3600 * 1 # 1 hour cache

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
      Common::Collection.fetch(::Prescription, cache_key: cache_key('getactiverx'), ttl: CACHE_TTL) do
        perform(:get, 'prescription/getactiverx', nil, token_headers).body
      end
    end

    ##
    # Get a list of active Prescriptions using new model PrescriptionDetails
    #
    # @return [Common::Collection[PrescriptionDetails]]
    #
    def get_active_rxs_with_details
      Common::Collection.fetch(::PrescriptionDetails, cache_key: cache_key('getactiverx'), ttl: CACHE_TTL) do
        perform(:get, 'prescription/getactiverx', nil, token_headers).body
      end
    end

    ##
    # Get a list of all Prescriptions
    #
    # @return [Common::Collection[Prescription]]
    #
    def get_history_rxs
      Common::Collection.fetch(::Prescription, cache_key: cache_key('gethistoryrx'), ttl: CACHE_TTL) do
        perform(:get, 'prescription/gethistoryrx', nil, token_headers).body
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
        perform(:get, 'prescription/medications', nil, token_headers).body
      end
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
      json = perform(:get, "prescription/rxtracking/#{id}", nil, token_headers).body
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
      json = perform(:get, "prescription/rxtracking/#{id}", nil, token_headers).body
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
      if (result = perform(:post, 'prescription/rxrefill', ids, token_headers))
        Common::Collection.bust([cache_key('getactiverx'), cache_key('gethistoryrx')])
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
      if (result = perform(:post, "prescription/rxrefill/#{id}", nil, token_headers))
        Common::Collection.bust([cache_key('getactiverx'), cache_key('gethistoryrx')])
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

    private

    def cache_key(action)
      return nil unless config.caching_enabled?
      return nil if session.user_id.blank?

      "#{session.user_id}:#{action}"
    end

    # NOTE: After June 17, MHV will roll out an improvement that collapses these
    # into a single endpoint so that you do not need to make multiple distinct
    # requests. They will keep these around for some time and eventually deprecate.

    # Current Email Account that receives notifications
    def get_notification_email_address
      config.parallel_connection.get('preferences/email', nil, token_headers).body
    end

    # Current Rx preference setting
    def get_rx_preference_flag
      config.parallel_connection.get('preferences/rx', nil, token_headers).body
    end

    # Change Email Account that receives notifications
    def post_notification_email_address(params)
      config.parallel_connection.post('preferences/email', params, token_headers)
    end

    # Change Rx preference setting
    def post_rx_preference_flag(params)
      params = { flag: params[:rx_flag] }
      config.parallel_connection.post('preferences/rx', params, token_headers)
    end
  end
end
