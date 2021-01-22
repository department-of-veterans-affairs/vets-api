# frozen_string_literal: true

require 'common/client/configuration/rest'

module SearchClickTracking
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = 30

    def base_path
      "#{Settings.search_click_tracking.url}/clicks/"
    end

    def service_name
      'SearchClickTracking'
    end
  end
end
