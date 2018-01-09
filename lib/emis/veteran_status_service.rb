# frozen_string_literal: true

require 'emis/service'
require 'emis/veteran_status_configuration'

module EMIS
  class VeteranStatusService < Service
    configuration EMIS::VeteranStatusConfiguration

    create_endpoints(%i(get_veteran_status))

    protected

    def custom_namespaces
      Settings.emis.veteran_status.soap_namespaces
    end
  end
end
