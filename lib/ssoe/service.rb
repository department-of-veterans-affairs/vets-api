# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'ssoe/configuration'
require 'nokogiri'

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

    # rubocop:disable Metrics/ParameterLists
    def get_traits(credential_method: nil,
                   credential_id: nil,
                   first_name: nil,
                   last_name: nil,
                   birth_date: nil,
                   ssn: nil,
                   email: nil,
                   phone: nil,
                   street1: nil,
                   city: nil,
                   state: nil,
                   zipcode: nil)
      with_monitoring do
        raw_response = perform(
          :post, '', build_message(credential_method, credential_id, first_name, last_name, birth_date,
                                   ssn, email, phone, street1, city, state, zipcode),
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

    def build_message(credential_method, credential_id, first_name, last_name, birth_date, ssn, email, phone, street1,
                      city, state, zipcode)
      SSOe::GetSSOeTraitsByCspidMessage.new(
        credential_method:,
        credential_id:,
        first_name:,
        last_name:,
        birth_date:,
        ssn:,
        email:,
        phone:,
        street1:,
        city:,
        state:,
        zipcode:
      ).perform
    end
    # rubocop:enable Metrics/ParameterLists

    def parse_response(response_body)
      doc = Nokogiri::XML(response_body)
      doc.remove_namespaces!

      icn = extract_icn(doc)
      return { success: true, icn: } if icn.present?

      fault = extract_fault(doc)
      return fault if fault

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
