# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'ssoe/configuration'

module SSOe
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    configuration SSOe::Configuration

    STATSD_KEY_PREFIX = 'api.ssoe'
    CONNECTION_ERRORS = [
      Faraday::ConnectionFailed,
      Faraday::TimeoutError,
      Common::Client::Errors::ClientError,
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
      error_response(e, :client, e.status)
    rescue *CONNECTION_ERRORS => e
      return parse_response(e.response.body) if e.respond_to?(:response) && e.response&.body

      error_response(e, :connection, 502)
    rescue => e
      error_response(e, :unknown, 500)
    end

    private

    def error_response(e, type, code)
      Rails.logger.error("[SSOe::Service::get_traits] #{type} error: #{e.class} - #{e.message}")

      {
        success: false,
        error: {
          code:,
          message: e.message
        }
      }
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

        return {
          success: false,
          error: {
            code: fault_code,
            message: fault_string
          }
        }
      end

      raise StandardError, 'Unable to parse SOAP response'
    end
  end
end
