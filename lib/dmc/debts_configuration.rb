# frozen_string_literal: true

require 'dmc/base_configuration'

module DMC
  class DebtsConfiguration < DMC::BaseConfiguration
    def service_name
      'Debts'
    end

    def mock_enabled?
      Settings.dmc.mock_debts
    end
  end
end
