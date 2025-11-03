# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'ssoe/configuration'
require 'ssoe/errors'

module SSOe
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    configuration SSOe::Configuration

    STATSD_KEY_PREFIX = 'api.ssoe'

    # rubocop:disable Metrics/MethodLength
    def get_traits(credential_method:, credential_id:, user:, address:)
      with_monitoring do
        raw_response = perform(
          :post,
          '',
          build_message(credential_method, credential_id, user, address),
          soapaction: nil
        )
        parse_response(raw_response.body, raw_response&.status)
      end
    rescue Common::Client::Errors::ClientError => e
      error_response(e, SSOe::Errors::RequestError, :client, e.status, e.body)
    rescue Faraday::ConnectionFailed => e
      error_response(e, SSOe::Errors::ConnectionError, :connection, 502)
    rescue Faraday::TimeoutError => e
      error_response(e, SSOe::Errors::TimeoutError, :timeout, 504)
    rescue Common::Exceptions::GatewayTimeout => e
      error_response(e, SSOe::Errors::TimeoutError, :gateway_timeout, 504)
    rescue Breakers::OutageException => e
      error_response(e, SSOe::Errors::ConnectionError, :outage, 503)
    rescue => e
      error_response(e, SSOe::Errors::UnknownError, :unknown, 500)
    end
    # rubocop:enable Metrics/MethodLength

    private

    def error_response(original_error, error_class, type, status, body = nil)
      Rails.logger.error(
        "[SSOe::Service::get_traits] #{type} error: #{original_error.class} - #{original_error.message}"
      )

      raise error_class.new(
        original_error.message,
        status:,
        body:
      )
    end

    def build_message(credential_method, credential_id, user, address)
      SSOe::GetSSOeTraitsByCspidMessage.new(
        credential_method:,
        credential_id:,
        first_name: user.first_name,
        last_name: user.last_name,
        birth_date: user.birth_date,
        ssn: user.ssn,
        email: user.email,
        phone: user.phone,
        street1: address.street1,
        city: address.city,
        state: address.state,
        zipcode: address.zipcode
      ).perform
    end

    def parse_response(response_body, status = nil)
      parsed = Hash.from_xml(Ox.dump(response_body))
      icn = parsed.dig('Envelope', 'Body', 'getSSOeTraitsByCSPIDResponse', 'icn')

      return { success: true, icn: } if icn.present?

      if parsed.dig('Envelope', 'Body', 'Fault')
        fault_code = parsed.dig('Envelope', 'Body', 'Fault', 'faultcode') || 'UnknownError'
        fault_string = parsed.dig('Envelope', 'Body', 'Fault', 'faultstring') || 'Unable to parse SOAP response'

        raise SSOe::Errors::SOAPFaultError.new(
          fault_string,
          fault_code:,
          body: response_body,
          status: status || 400
        )
      end

      raise SSOe::Errors::SOAPParseError.new(
        'Unable to parse SOAP response',
        body: response_body,
        status: status || 500
      )
    end
  end
end
