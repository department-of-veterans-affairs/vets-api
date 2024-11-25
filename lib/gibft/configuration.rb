# frozen_string_literal: true

require 'salesforce/configuration'

module Gibft
  class Configuration < Salesforce::Configuration
    # Settings.salesforce-gibft
    SALESFORCE_INSTANCE_URL = Settings['salesforce-gibft'].url

    def service_name
      'GIBFT'
    end
  end
end
