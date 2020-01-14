# frozen_string_literal: true

require 'evss/base_service'

module EVSS
  class CommonService < BaseService
    API_VERSION = Settings.evss.versions.common
    BASE_URL = "#{Settings.evss.url}/wss-common-services-web-#{API_VERSION}/rest/"

    def initialize(*args)
      super
      @use_mock = Settings.evss.mock_common_service || false
    end

    def create_user_account
      post 'persistentPropertiesService/11.6/createUserAccount'
    end

    def get_current_info
      post 'vsoSearch/11.6/getCurrentInfo'
    end

    def get_rating_info
      msg_body = { 'participantId' => @headers['va_eauth_pid'] }
      headers = { 'Content-Type' => 'application/json' }
      raw_response = post 'ratingInfoService/11.6/findRatingInfoPID', msg_body.to_json, headers
      EVSS::DisabilityCompensationForm::RatingInfoResponse.new(raw_response.status, raw_response)
    end

    def self.breakers_service
      BaseService.create_breakers_service(name: 'EVSS/Common', url: BASE_URL)
    end
  end
end
