# frozen_string_literal: true

require 'emis/service'
require 'emis/veteran_status_configuration'

module EMIS
  class MockVeteranStatusService < VeteranStatusService
    configuration EMIS::MockVeteranStatusConfig
  end
end
