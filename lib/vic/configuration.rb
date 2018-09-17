# frozen_string_literal: true

module VIC
  class Configuration < Salesforce::Configuration
    SALESFORCE_INSTANCE_URL = Settings.salesforce.url

    def service_name
      'VIC2'
    end
  end
end
