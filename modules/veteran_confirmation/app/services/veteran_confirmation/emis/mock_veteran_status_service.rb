# frozen_string_literal: true

require 'emis/service'
require 'emis/veteran_status_configuration'

module EMIS
  # HTTP Client for EMIS Veteran Status Service requests.
  class VeteranStatusService < Service
    configuration EMIS::MockVeteranStatusConfig
  end
end
