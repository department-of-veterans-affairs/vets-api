# frozen_string_literal: true
require 'emis/service'
require 'emis/military_information_configuration'
require 'emis/errors/errors'

module EMIS
  class MilitaryInformationService < Service
    configuration EMIS::MilitaryInformationConfiguration

    def get_veteran_status(edipi: nil, icn: nil)
      make_request(
        edipi: edipi,
        icn: icn,
        operation: 'getVeteranStatus',
        response_type: EMIS::Responses::GetVeteranStatusResponse
      )
    end
  end
end
