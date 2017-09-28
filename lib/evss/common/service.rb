# frozen_string_literal: true
module EVSS
  module Common
    class Service < EVSS::Service
      configuration EVSS::Common::Configuration

      def initialize(current_user)
        @current_user = current_user
      end

      def find_rating_info(participant_id)
        perform_with_user_headers(
          :post,
          'ratingInfoService/11.0/findRatingInfoPID',
          { participantId: participant_id }.to_json
        )
      end

      def create_user_account
        perform_with_user_headers(
          :post,
          'persistentPropertiesService/11.0/createUserAccount',
          nil
        )
      end
    end
  end
end
