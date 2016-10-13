# frozen_string_literal: true
require_dependency 'evss/base_service'

module EVSS
  class CommonService < BaseService
    def find_rating_info(participant_id)
      post 'ratingInfoService/11.1/findRatingInfoPID',
           { participantId: participant_id }.to_json
    end

    def create_user_account
      post 'persistentPropertiesService/11.1/createUserAccount'
    end

    protected

    def base_url
      "#{ENV['EVSS_BASE_URL']}/wss-common-services-web-11.1/rest/"
    end
  end
end
