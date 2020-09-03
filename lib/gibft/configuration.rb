# frozen_string_literal: true

module Gibft
  class Configuration < Salesforce::Configuration
    SALESFORCE_INSTANCE_URL = Settings['salesforce-gibft'].url

    def service_name
      'GIBFT'
    end
  end
end
