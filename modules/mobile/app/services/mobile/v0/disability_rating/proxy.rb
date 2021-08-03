# frozen_string_literal: true

require 'common/exceptions'

module Mobile
  module V0
    module DisabilityRating
      class Proxy
        def initialize(user)
          @user = user
        end

        def get_disability_ratings
          response = rating_service.rating.find_rating_data(@user.ssn)
          handle_errors!(response)
          Mobile::V0::Adapters::Rating.new.disability_ratings(response)
        end

        private

        def rating_service
          @rating_service ||= BGS::Services.new(external_uid: @user.icn, external_key: @user.email)
        end

        def handle_errors!(response)
          raise_error! unless response[:disability_rating_record].instance_of?(Hash)
        end

        def raise_error!
          raise Common::Exceptions::BackendServiceException.new(
            'BGS_RTG_502',
            source: self.class.to_s
          )
        end
      end
    end
  end
end
