# frozen_string_literal: true

module CARMA
  class Configuration < Salesforce::Configuration
    SALESFORCE_INSTANCE_URL = Settings['salesforce-carma'].url

    def service_name
      'CARMA'
    end
  end
end
