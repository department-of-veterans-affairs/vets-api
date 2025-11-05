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
        parse_response(raw_response.body)
      end
    rescue Common::Client::Errors::ClientError => e
      error_response(e, SSOe::Errors::RequestError, :client)
    rescue Faraday::ConnectionFailed => e
      error_response(e, SSOe::Errors::ConnectionError, :connection)
    rescue Faraday::TimeoutError => e
      error_response(e, SSOe::Errors::TimeoutError, :timeout)
    rescue Common::Exceptions::GatewayTimeout => e
      error_response(e, SSOe::Errors::TimeoutError, :gateway_timeout)
    rescue Breakers::OutageException => e
      error_response(e, SSOe::Errors::ConnectionError, :outage)
    rescue => e
      error_response(e, SSOe::Errors::UnknownError, :unknown)
    end
    # rubocop:enable Metrics/MethodLength

    private

    def error_response(original_error, error_class, type)
      Rails.logger.error(
        "[SSOe::Service::get_traits] #{type} error: #{original_error.class} - #{original_error.message}"
      )

      raise error_class, "[SSOe][Service] #{type.to_s.capitalize} error - #{original_error.message}"
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

    def parse_response(response_body)
      parsed = Hash.from_xml(Ox.dump(response_body))
      icn = parsed.dig('Envelope', 'Body', 'getSSOeTraitsByCSPIDResponse', 'icn')

      return { success: true, icn: } if icn.present?

      if parsed.dig('Envelope', 'Body', 'Fault')
        fault_code = parsed.dig('Envelope', 'Body', 'Fault', 'faultcode') || 'UnknownError'
        fault_string = parsed.dig('Envelope', 'Body', 'Fault', 'faultstring') || 'Unable to parse SOAP response'

        raise SSOe::Errors::SOAPFaultError, "[SSOe][Service] SOAP Fault - #{fault_string} (Code: #{fault_code})"
      end

      raise SSOe::Errors::SOAPParseError, '[SSOe][Service] Unable to parse SOAP response'
    end
  end
end
