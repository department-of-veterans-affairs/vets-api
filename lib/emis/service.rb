# frozen_string_literal: true
require 'common/client/base'
require 'emis/configuration'
require 'emis/messages/edipi_or_icn_message'
require 'emis/responses/error_response'
require 'emis/responses/get_veteran_status_response'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'
require 'emis/errors/errors'

module EMIS
  class Service < Common::Client::Base
    protected

    def make_request(edipi: nil, icn: nil, operation:, response_type:)
      message = create_edipi_or_icn_message(edipi: edipi, icn: icn)
      raw_response = perform(
        :post,
        '',
        message,
        soapaction: "http://viers.va.gov/cdi/eMIS/#{operation}/v1"
      )
      response_type.new(raw_response)
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error "eMIS connection failed: #{e.message}"
      EMIS::Responses::ErrorResponse.new(e)
    rescue Common::Client::Errors::ClientError => e
      Rails.logger.error "eMIS error: #{e.message}"
      EMIS::Responses::ErrorResponse.new(e)
    end

    def create_edipi_or_icn_message(edipi:, icn:)
      EMIS::Messages::EdipiOrIcnMessage.new(edipi: edipi, icn: icn).to_xml
    end
  end
end
