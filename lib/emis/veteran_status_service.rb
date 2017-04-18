# frozen_string_literal: true
require 'emis/service'
require 'emis/veteran_status_configuration'
require 'emis/errors/errors'

module EMIS
  class VeteranStatusService < Service
    configuration EMIS::VeteranStatusConfiguration

    create_endpoints(%i(get_veteran_status))
  end
end
