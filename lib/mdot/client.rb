# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/exceptions/gateway_timeout'
require_relative 'configuration'
require_relative 'response'
require_relative 'token'
require_relative 'exceptions/key'
require_relative 'exceptions/service_exception'

module MDOT
  ##
  # Medical Devices Ordering Tool
  #
  # This service integrates with the DLC API and allows veterans
  # to reorder medical devices such as hearing aid batteries.
  #

  class Client < Common::Client::Base
    include Common::Client::Concerns::Monitoring

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
          schema: :supplies,
          uuid: @user.uuid
        )
      end
    end

    ##
    # POSTs to DLC endpoint to create a new order.
    #
    # @return [Faraday::Response] Faraday response instance.
    #
    def submit_order(request_body)
      request_body.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
      raise_backend_exception('MDOT_supplies_not_selected') if request_body['order'].blank?

      with_monitoring_and_error_handling do
        perform(:post, @supplies, request_body, submission_headers).body
      end
    end

    private

    def headers
      {
        VA_VETERAN_FIRST_NAME: @user.first_name,
        VA_VETERAN_MIDDLE_NAME: @user.middle_name,
        VA_VETERAN_LAST_NAME: @user.last_name,
        VA_VETERAN_ID: @user.ssn.to_s.last(4),
        VA_VETERAN_BIRTH_DATE: @user.birth_date,
        VA_ICN: @user.icn
      }
    end

    def submission_headers
      {
        VAAPIKEY: handle_token
      }
    end

    def with_monitoring_and_error_handling(&)
      with_monitoring(2, &)
    rescue => e
      handle_error(e)
    end

    def save_error_details(error)
      Sentry.set_tags(external_service: self.class.to_s.underscore)

      Sentry.set_extras(
        url: config.base_path,
        message: error.message,
        body: error.body
      )
    end

    def raise_backend_exception(key, source = self.class, error = nil)
      raise MDOT::Exceptions::ServiceException.new(
        MDOT::ExceptionKey.new(key),
        { source: source.to_s },
        error&.status,
        error&.body
      )
    end

    def handle_client_error(error)
      code =
        if error.try(:status) == 401
          'MDOT_unauthorized'
        elsif error.try(:status) == 500
          'MDOT_internal_server_error'
        elsif error.try(:status) == 503
          'MDOT_service_unavailable'
        elsif error.try(:body) && error.body.try(:fetch, 'result', nil)
          "MDOT_#{error.body['result'].downcase}"
        else
          'default_exception'
        end

      raise_backend_exception(code, self.class, error)
    end

    def handle_error(error)
      save_error_details(error)
      case error
      when Faraday::ParsingError
        raise_backend_exception('MDOT_502')
      when Common::Client::Errors::ClientError
        handle_client_error(error)
      else
        raise error
      end
    end

    def handle_token
      existing_token = MDOT::Token.find(@user.uuid)
      if !existing_token || existing_token.ttl < 5
        get_supplies
      end
      MDOT::Token.find(@user.uuid).try(:token)
    end
  end
end
