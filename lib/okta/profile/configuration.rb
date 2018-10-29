# frozen_string_literal: true

require 'okta/configuration.rb'

module Okta
  module Profile
    class Configuration < Okta::Configuration
      def base_path
        Settings.oidc.profile_api_url || 'https://deptva-eval.okta.com/api/v1/users/'
      end
    end
  end
end
