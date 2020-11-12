# frozen_string_literal: true

require 'emis/service'
require 'emis/veteran_status_service'
require_relative '../../../config/mock_veteran_status_config'

module EMIS
  class MockVeteranStatusService < VeteranStatusService
    configuration EMIS::MockVeteranStatusConfig
  end
end
