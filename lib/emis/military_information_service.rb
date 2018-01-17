# frozen_string_literal: true

require 'emis/service'
require 'emis/military_information_configuration'

module EMIS
  class MilitaryInformationService < Service
    configuration EMIS::MilitaryInformationConfiguration

    create_endpoints(
      [
        :get_deployment,
        :get_disabilities,
        :get_guard_reserve_service_periods,
        [:get_military_service_eligibility_info, 'militaryServiceEligibilityRequest'],
        :get_military_occupation,
        [:get_military_service_episodes, 'serviceEpisodeRequest'],
        :get_retirement,
        :get_unit_information
      ]
    )

    protected

    def custom_namespaces
      Settings.emis.military_information.soap_namespaces
    end
  end
end
