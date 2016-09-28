# frozen_string_literal: true
require_dependency 'evss/base_service'

module EVSS
  class CommonService < BaseService
    def find_rating_info
      post 'ratingInfoService/11.1/findRatingInfoPID',
           { participantId: @user.participant_id }.to_json
    end

    protected

    def base_url
      ENV['EVSS_COMMON_BASE_URL']
    end
  end
end
