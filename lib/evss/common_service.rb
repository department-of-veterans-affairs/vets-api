# frozen_string_literal: true
require 'evss/base_service'

module EVSS
  class CommonService < BaseService
    BASE_URL = "#{ENV['EVSS_BASE_URL']}/wss-common-services-web-11.0/rest/"

    def find_rating_info(participant_id)
      post 'ratingInfoService/11.0/findRatingInfoPID',
           { participantId: participant_id }.to_json
    end

    def create_user_account
      post 'persistentPropertiesService/11.0/createUserAccount'
    end

    def self.breakers_service
      BaseService.create_breakers_service(name: 'EVSS/Common', url: BASE_URL)
    end
  end
end
