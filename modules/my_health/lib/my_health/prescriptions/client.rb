# frozen_string_literal: true

require 'common/client/base'
require 'my_health/prescriptions/configuration'

module MyHealth
  module Prescriptions
    class Client < Common::Client::Base
      configuration MyHealth::Prescriptions::Configuration

      attr_reader :session

      def initialize(opts = {})
        @session = if opts.is_a?(Hash) && opts.key?(:session)
                     opts[:session]
                   else
                     { user_id: nil }
                   end
        super()
      end


      def get_all_rxs
        perform(:get, 'prescription/gethistoryrx', nil, token_headers)
      end

      def get_history_rxs
        get_all_rxs
      end

      def get_active_rxs
        perform(:get, 'prescription/getactiverx', nil, token_headers)
      end

      def get_rx_details(id)
        perform(:get, "prescription/rxrefill/#{id}", nil, token_headers)
      end

      def get_active_rxs_with_details
        get_active_rxs
      end

      def post_refill_rx(id)
        perform(:post, "prescription/rxrefill/#{id}", nil, token_headers)
      end

      def get_session
        @session
      end

      def user_id
        @session[:user_id]
      end

      private

      def token_headers
        config.base_request_headers
      end
    end
  end
end
