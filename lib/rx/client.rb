# frozen_string_literal: true
require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'rx/configuration'
require 'rx/client_session'

module Rx
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    include Common::Client::MHVSessionBasedClient

    configuration Rx::Configuration
    client_session Rx::ClientSession

    def get_active_rxs
      json = perform(:get, 'prescription/getactiverx', nil, token_headers).body
      Common::Collection.new(::Prescription, json)
    end

    def get_history_rxs
      json = perform(:get, 'prescription/gethistoryrx', nil, token_headers).body
      Common::Collection.new(::Prescription, json)
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
      perform(:post, "prescription/rxrefill/#{id}", nil, token_headers)
    end
  end
end
