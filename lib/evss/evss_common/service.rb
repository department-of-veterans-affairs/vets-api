# frozen_string_literal: true
module EVSS
  module EVSSCommon
    class Service < EVSS::Service
      configuration EVSS::EVSSCommon::Configuration

      def find_rating_info
        perform_with_user_headers(
          :post,
          'ratingInfoService/11.0/findRatingInfoPID',
          { participantId: @current_user.participant_id }.to_json
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
