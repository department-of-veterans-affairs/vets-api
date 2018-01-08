# frozen_string_literal: true
require 'evss/base_service'

module EVSS
  class CommonService < BaseService
    API_VERSION = Settings.evss.versions.common
    BASE_URL = "#{Settings.evss.url}/wss-common-services-web-#{API_VERSION}/rest/"

    def create_user_account
      post 'persistentPropertiesService/11.0/createUserAccount'
    end

    def self.breakers_service
      BaseService.create_breakers_service(name: 'EVSS/Common', url: BASE_URL)
    end
  end
end
