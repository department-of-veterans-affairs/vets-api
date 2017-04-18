# frozen_string_literal: true
require 'emis/service'
require 'emis/military_information_configuration'
require 'emis/errors/errors'

module EMIS
  class MilitaryInformationService < Service
    configuration EMIS::MilitaryInformationConfiguration

    create_endpoints(
      %i(
        get_deployment
        get_disabilities
        get_guard_reserve_service_periods
        get_military_service_eligibility_info
        get_military_occupation
        get_military_service_episodes
        get_retirement
        get_unit_information
      )
    )
  end
end
