# frozen_string_literal: true
require 'common/client/configuration/rest'

module UnifiedHealthData
  class Configuration < Common::Client::Configuration::REST
    def base_path
      'https://api.unifiedhealthdata.example.com'
    end

    def service_name
      'UnifiedHealthData'
    end
  end
end
