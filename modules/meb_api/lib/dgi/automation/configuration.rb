# frozen_string_literal: true

require 'dgi/configuration'

module MebApi
  module DGI
    module Automation
      class Configuration < MebApi::DGI::Configuration
        def base_path
          Settings.dgi['veteran-services'].url.to_s
        end

        def service_name
          'DGI/Automation'
        end

        def mock_enabled?
          Settings.dgi['veteran-services'].mock || false
        end
      end
    end
  end
end
