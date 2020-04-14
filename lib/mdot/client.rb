# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/exceptions/external/gateway_timeout'
require 'mdot/configuration'
require 'mdot/response'
require 'mdot/exceptions/key'
require 'mdot/exceptions/service_exception'

module MDOT
  ##
  # Medical Devices Ordering Tool
  #
  # This service integrates with the DLC API and allows veterans
  # to reorder medical devices such as hearing aid batteries.
  #

  class Client < Common::Client::Base
    include Common::Client::Monitoring

    configuration MDOT::Configuration

    STATSD_KEY_PREFIX = 'api.mdot'

    def initialize(current_user)
      @user = current_user
      @supplies = 'supplies'
    end

    ##
    # GETs medical supplies available for reorder for veteran.
    #
    # @return [Faraday::Response] Faraday response instance.
    #
    def get_supplies
      with_monitoring_and_error_handling do
        raw_response = perform(:get, @supplies, nil, headers)

        MDOT::Response.new(
          response: raw_response,
          schema: :supplies
        )
      end
    end

    ##
    # POSTs to DLC endpoint to create a new order.
    #
    # @return [Faraday::Response] Faraday response instance.
    #
    def submit_order(request_body)
      with_monitoring_and_error_handling do
        perform(:post, @supplies, request_body, headers).body
      end
    end

    private

    def headers
      {
        VA_VETERAN_ID: @user.ssn.last(4),
        VA_VETERAN_BIRTH_DATE: @user.birth_date
      }
    end

    def with_monitoring_and_error_handling
      with_monitoring(2) do
        yield
      end
    rescue => e
      handle_error(e)
    end

    def save_error_details(error)
      Raven.tags_context(
        external_service: self.class.to_s.underscore
      )

      Raven.extra_context(
        url: config.base_path,
        message: error.message,
        body: error.body
      )
    end

    def raise_backend_exception(key, source, error = nil)
      exception = MDOT::ServiceException.new(
        key,
        { source: source.to_s },
        error&.status,
        error&.body
      )
      raise exception
    end

    def handle_parsing_error(error)
      Raven.extra_context(
        message: error.message,
        url: config.base_path
      )
      raise_backend_exception(
        MDOT::ExceptionKey.new('MDOT_502'),
        self.class
      )
    end

    def handle_client_error(error)
      save_error_details(error)
      code = error.body['errors'].first.dig('code')
      raise_backend_exception(
        MDOT::ExceptionKey.new("MDOT_#{code}"),
        self.class,
        error
      )
    end

    def handle_error(error)
      case error
      when Faraday::ParsingError
        handle_parsing_error(error)
      when Common::Client::Errors::ClientError
        handle_client_error(error)
      else
        raise error
      end
    end
  end
end
