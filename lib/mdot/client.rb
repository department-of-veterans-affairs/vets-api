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
        raw_response = perform(:get, @supplies, nil, headers)
        MDOT::Response.new response: raw_response, schema: :supplies
      end
    end

    ##
    # POSTs to DLC endpoint to create a new order.
    #
    # @return [Faraday::Response] Faraday response instance.
    #
    def submit_order(request_body)
      with_monitoring_and_error_handling do
        raw_response = perform(:post, @supplies, request_body, headers)
        MDOT::Response.new response: raw_response, schema: :submit
      end
    end

    private

    def headers
      { veteranId: user.ssn }
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
      raise MDOT::ServiceException.new(
        key,
        { source: source.to_s },
        error&.status,
        error&.body
      )
    end

    def handle_error(error)
      case error
      when Faraday::ParsingError
        Raven.extra_context(
          message: error.message,
          url: config.base_path
        )
        raise_backend_exception('MDOT_502', self.class)
      when Common::Client::Errors::ClientError
        save_error_details(error)
        raise Common::Exceptions::Forbidden if error.status == 403

        code = error.body['errors'].first.dig('code')
        raise_backend_exception("MDOT_#{code}", self.class, error)
      else
        raise error
      end
    end
  end
end
