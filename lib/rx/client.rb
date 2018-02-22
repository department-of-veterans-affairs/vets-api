# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'rx/configuration'
require 'rx/client_session'
require 'active_support/core_ext/hash/slice'

module Rx
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    include Common::Client::MHVSessionBasedClient

    configuration Rx::Configuration
    client_session Rx::ClientSession

    CACHE_TTL = 3600 * 10 # 10 hour cache

    def get_active_rxs
      Common::Collection.fetch(::Prescription, cache_key: cache_key('getactiverx'), ttl: CACHE_TTL) do
        perform(:get, 'prescription/getactiverx', nil, token_headers).body
      end
    end

    def get_history_rxs
      Common::Collection.fetch(::Prescription, cache_key: cache_key('gethistoryrx'), ttl: CACHE_TTL) do
        perform(:get, 'prescription/gethistoryrx', nil, token_headers).body
      end
    end

    def get_rx(id)
      collection = get_history_rxs
      collection.find_first_by('prescription_id' => { 'eq' => id })
    end

    def get_tracking_rx(id)
      json = perform(:get, "prescription/rxtracking/#{id}", nil, token_headers).body
      data = json[:data].first.merge(prescription_id: id)
      Tracking.new(json.merge(data: data))
    end

    def get_tracking_history_rx(id)
      json = perform(:get, "prescription/rxtracking/#{id}", nil, token_headers).body
      tracking_history = json[:data].map { |t| Hash[t].merge(prescription_id: id) }
      Common::Collection.new(::Tracking, json.merge(data: tracking_history))
    end

    def post_refill_rx(id)
      if (result = perform(:post, "prescription/rxrefill/#{id}", nil, token_headers))
        Common::Collection.bust([cache_key('getactiverx'), cache_key('gethistoryrx')])
      end
      result
    end

    # TODO: Might need better error handling around this.
    def get_preferences
      response = {}
      config.parallel_connection.in_parallel do
        response.merge!(get_notification_email_address)
        response.merge!(rx_flag: get_rx_preference_flag[:flag])
      end
      PrescriptionPreference.new(response)
    end

    # Dont do this one in parallel since you want it to behave like a single atomic operation
    def post_preferences(params)
      mhv_params = PrescriptionPreference.new(params).mhv_params
      post_notification_email_address(mhv_params.slice(:email_address))
      post_rx_preference_flag(mhv_params.slice(:rx_flag))
      get_preferences
      # NOTE: email_address might return an MHV error for any validations we have not handled, these will result
      # in a mapped RX157 code in exceptions.en.yml
    end

    private

    def cache_key(action)
      return nil unless config.caching_enabled?
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
