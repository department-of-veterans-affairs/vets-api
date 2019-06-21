# frozen_string_literal: true

module Vsp
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.evss.letters.timeout || 55

    def base_path
      Settings.vsp.url
    end

    def service_name
      'VSP/HelloWorld'
    end

    def mock_enabled?
      false
    end
  end
end
