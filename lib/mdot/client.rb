# frozen_string_literal: true

require 'common/client/base'

module MDOT
  ##
  # Medical Devices Ordering Tool
  #
  # This service integrates with the DLC API and allows veterans
  # to reorder medical devices such as hearing aid batteries.
  #

  class Client < Common::Client::Base
    configuration MDOT::Configuration

    def initialize(current_user)
      @user = current_user
      @supplies = 'mdot/supplies'
    end

    ##
    # GETs medical supplies available for reorder for veteran.
    #
    # @return [Faraday::Response] Faraday response instance.
    #
    def get_supplies
      with_monitoring_and_error_handling do
        raw_response = perform(:get, @supplies, request_body)
        MDOT::Response.new response: raw_response, schema: :supplies
      end
    end

    ##
    # POSTs to DLC endpoint to create a new order.
    #
    # @return [Faraday::Response] Faraday response instance.
    #
    def submit_order
      with_monitoring_and_error_handling do
        raw_response = perform(:post, @supplies, request_body)
        MDOT::Response.new response: raw_response, schema: :submit
      end
    end
  end
end
