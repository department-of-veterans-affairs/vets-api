# frozen_string_literal: true
require 'emis/service'
require 'emis/veteran_status_configuration'
require 'emis/errors/errors'

module EMIS
  class VeteranStatusService < Service
    configuration EMIS::VeteranStatusConfiguration

    def get_veteran_status(edipi)
      raw_response = perform(:post, '', create_edipi_message(edipi), soapaction: 'getVeteranStatus')
      EMIS::Responses::GetVeteranStatusResponse.new(raw_response)
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error "eMIS get_veteran_status connection failed: #{e.message}"
      EMIS::Responses::GetVeteranStatusResponse.with_server_error
    rescue Common::Client::Errors::ClientError => e
      Rails.logger.error "eMIS get_veteran_status error: #{e.message}"
      EMIS::Responses::GetVeteranStatusResponse.with_server_error
    end
  end
end
