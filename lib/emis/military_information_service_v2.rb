# frozen_string_literal: true

require 'emis/service'
require 'emis/military_information_configuration_v2'

module EMIS
  # HTTP Client for EMIS Military Information Service requests.
  class MilitaryInformationServiceV2 < Service
    configuration EMIS::MilitaryInformationConfigurationV2

    create_endpoints(
      [
        [:get_deployment, 'deploymentRequest', 'V2'],
        [:get_guard_reserve_service_periods, 'guardReserveServicePeriodsRequest', 'V2'],
        [:get_military_service_episodes, 'serviceEpisodeRequest', 'V2']
      ]
    )

    protected

    # Custom namespaces used in EMIS SOAP request message
    # @return [Config::Options] Custom namespaces object
    def custom_namespaces
      Settings.emis.military_information.v2.soap_namespaces
    end
  end
end
