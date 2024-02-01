# frozen_string_literal: true

require 'emis/service'
require 'emis/veteran_status_configuration'

module EMIS
  # HTTP Client for EMIS Veteran Status Service requests.
  class VeteranStatusService < Service
    configuration EMIS::VeteranStatusConfiguration

    create_endpoints(%i[get_veteran_status])

    protected

    # Custom namespaces used in EMIS SOAP request message
    # @return [Config::Options] Custom namespaces object
    def custom_namespaces
      Settings.emis.veteran_status.soap_namespaces
    end
  end
end
