# frozen_string_literal: true

require 'emis/service'
require 'emis/military_information_configuration'

module EMIS
  # HTTP Client for EMIS Military Information Service requests.
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

    # Custom namespaces used in EMIS SOAP request message
    # @return [Config::Options] Custom namespaces object
    def custom_namespaces
      Settings.emis.military_information.v1.soap_namespaces
    end
  end
end
