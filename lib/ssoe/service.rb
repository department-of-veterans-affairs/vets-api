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
      nil
    rescue => e
      Rails.logger.error("[SSOe::Service::get_traits] Unexpected error: #{e.class} - #{e.message}")
      nil
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

      if parsed.dig('Envelope', 'Body', 'getSSOeTraitsByCSPIDResponse', 'icn')
        icn = parsed['Envelope']['Body']['getSSOeTraitsByCSPIDResponse']['icn']
        return { success: true, icn: } if icn.present?
      end

      if parsed.dig('Envelope', 'Body', 'Fault')
        fault_code = parsed.dig('Envelope', 'Body', 'Fault', 'faultcode')
        fault_string = parsed.dig('Envelope', 'Body', 'Fault', 'faultstring')

        return {
          success: false,
          error: {
            code: fault_code || 'UnknownError',
            message: fault_string || 'Unable to parse SOAP response'
          }
        }
      end

      unknown_error
    rescue => e
      Rails.logger.error("[SSOe::Service::parse_response] Error parsing response: #{e.class} - #{e.message}")
      unknown_error
    end

    def extract_icn(doc)
      doc.at_xpath('//getSSOeTraitsByCSPIDResponse/icn')&.text
    end

    def extract_fault(doc)
      fault = doc.at_xpath('//Fault')
      return unless fault

      fault_code = fault.at_xpath('faultcode')&.text
      fault_string = fault.at_xpath('faultstring')&.text
      {
        success: false,
        error: {
          code: fault_code,
          message: fault_string
        }
      }
    end

    def unknown_error
      {
        success: false,
        error: {
          code: 'UnknownError',
          message: 'Unable to parse SOAP response'
        }
      }
    end
  end
end
