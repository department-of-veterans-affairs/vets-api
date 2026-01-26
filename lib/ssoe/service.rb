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

    CONNECTION_ERRORS = [
      Faraday::ConnectionFailed,
      Faraday::TimeoutError,
      Common::Exceptions::GatewayTimeout,
      Breakers::OutageException
    ].freeze

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
      raise SSOe::Errors::RequestError, "[SSOe][Service] #{e.class} - #{e.message}"
    rescue *CONNECTION_ERRORS => e
      raise SSOe::Errors::ServerError, "[SSOe][Service] #{e.class} - #{e.message}"
    rescue SSOe::Errors::Error
      raise
    rescue => e
      raise SSOe::Errors::Error, "[SSOe][Service] #{e.class} - #{e.message}"
    end

    private

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

      check_for_fault(parsed)

      icn = parsed.dig('Envelope', 'Body', 'getSSOeTraitsByCSPIDResponse', 'icn')
      return { success: true, icn: } if icn.present?

      raise SSOe::Errors::ParsingError, '[SSOe][Service] Unable to parse SOAP response'
    end

    def check_for_fault(parsed)
      return unless parsed.dig('Envelope', 'Body', 'Fault')

      fault_code = parsed.dig('Envelope', 'Body', 'Fault', 'faultcode') || 'UnknownError'
      fault_string = parsed.dig('Envelope', 'Body', 'Fault', 'faultstring') || 'Unable to parse SOAP response'

      raise SSOe::Errors::ParsingError, "[SSOe][Service] SOAP Fault - #{fault_string} (Code: #{fault_code})"
    end
  end
end
