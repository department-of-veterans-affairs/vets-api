# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    module Dvp
      # An extension of the EVSS::DisabilityCompensationForm::Configuration that
      # points to the Digital Veterans Platform
      class Configuration < EVSS::DisabilityCompensationForm::Configuration
        def base_path
          "#{Settings.evss.dvp.url}/#{Settings.evss.service_name}/rest/form526/v2"
        end
      end
    end
  end
end
