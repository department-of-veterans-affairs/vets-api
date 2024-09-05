# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/request/multipart_request'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_custom_error'
require 'common/client/middleware/response/mhv_errors'
require 'common/client/middleware/response/snakecase'
require 'sm/middleware/response/sm_parser'

module Mobile
  module V0
    module Messaging
      ##
      # HTTP client configuration for {Mobile::V0::Messaging::Client},
      # sets the app token
      # For now the base_path and service_name are unchanged, i.e. this is
      # a shared service with distinct app_token.
      #
      class Configuration < SM::Configuration
        ##
        # @return [String] Client token set in `settings.yml` via credstash
        #
        def app_token
          Settings.mhv_mobile.sm.app_token
        end
      end
    end
  end
end
