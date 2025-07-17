# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'ssoe/configuration'
require 'ssoe/messages/get_ssoe_traits_by_cspid_message'
require 'nokogiri'

module SSOe
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    configuration SSOe::Configuration

    STATSD_KEY_PREFIX = 'api.ssoe'

    CONNECTION_ERRORS = [Faraday::ConnectionFailed,
                         Common::Client::Errors::ClientError,
                         Common::Exceptions::GatewayTimeout].freeze

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
          :post, '',
          SSOe::Messages::GetSSOeTraitsByCspidMessage.new(
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
          ).perform,
          soapaction: nil
        )
        parse_response(raw_response.body)
      end
    rescue *CONNECTION_ERRORS => e
      nil
    end

    private

    def parse_response(response_body)
      doc = Nokogiri::XML(response_body)
      doc.remove_namespaces!

      icn = doc.at_xpath('Envelope//getSSOeTraitsByCSPIDResponse/icn')&.text
      return { icn: } if icn

      fault = doc.at_xpath('Envelope//Fault')
      fault_code = fault&.at_xpath('faultcode')&.text
      fault_string = fault&.at_xpath('faultstring')&.text

      { fault_code:, fault_string: }
    end
  end
end