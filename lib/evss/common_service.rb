# frozen_string_literal: true

require 'evss/base_service'

module EVSS
  class CommonService < BaseService
    API_VERSION = Settings.evss.versions.common
    BASE_URL = "#{Settings.evss.url}/wss-common-services-web-#{API_VERSION}/rest/"

    def create_user_account
      post 'persistentPropertiesService/11.6/createUserAccount'
    end

    # :nocov:
    # Unable to write a vcr cassette for this EVSS API as it is not accessible in their
    # testing platform. Once they have rectified this, this nocov should be removed and
    # a proper test me made.
    def get_current_info
      post 'vsoSearch/11.6/getCurrentInfo'
    end
    # :nocov:

    def self.breakers_service
      BaseService.create_breakers_service(name: 'EVSS/Common', url: BASE_URL)
    end
  end
end
