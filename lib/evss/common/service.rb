# frozen_string_literal: true
module EVSS
  module Common
    class Service < EVSS::Service
      def find_rating_info(participant_id)
        post 'ratingInfoService/11.0/findRatingInfoPID',
             { participantId: participant_id }.to_json
      end

      def create_user_account
        post 'persistentPropertiesService/11.0/createUserAccount'
      end
    end
  end
end
