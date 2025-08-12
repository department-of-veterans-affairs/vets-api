# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'ssoe/configuration'

module SSOe
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    configuration SSOe::Configuration

    STATSD_KEY_PREFIX = 'api.ssoe'
    UNKNOWN_ERROR = {
      success: false,
      error: {
        code: 500,
        message: 'UnknownError: Unable to parse SOAP response'
      }
    }.freeze
    CONNECTION_ERROR = {
      success: false,
      error: {
        code: 502,
        message: 'Bad Gateway: Failed to connect'
      }
    }.freeze
    CONNECTION_ERRORS = [
      Faraday::ConnectionFailed,
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
    rescue *CONNECTION_ERRORS => e
      Rails.logger.error("[SSOe::Service::get_traits] Connection error: #{e.class} - #{e.message}")
      CONNECTION_ERROR
    rescue => e
      Rails.logger.error("[SSOe::Service::get_traits] Unexpected error: #{e.class} - #{e.message}")
      UNKNOWN_ERROR
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
      parsed = Hash.from_xml(response_body)
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
