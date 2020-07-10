# frozen_string_literal: true
require 'salesforce/configuration'

module VIC
  class Configuration < Salesforce::Configuration
    SALESFORCE_INSTANCE_URL = Settings.salesforce.url

    def service_name
      'VIC2'
    end
  end
end
