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
          combine_response = common_service.get_rating_info
          individual_response = compensation_service.get_rated_disabilities
          Mobile::V0::Adapters::Rating.new.disability_ratings(combine_response, individual_response)
        rescue => e
          status_code = e.respond_to?("response") ? e.response[:status] : e.status_code
          if status_code == 400
            raise Common::Exceptions::BackendServiceException, 'MOBL_404_rating_not_found'
          elsif status_code == 502
            raise Common::Exceptions::BackendServiceException, 'MOBL_502_upstream_error'
          elsif status_code == 403
            raise Common::Exceptions::BackendServiceException, 'MOBL_403_rating_forbidden'
          else
            raise e
          end
        end

        private

        def common_service
          EVSS::CommonService.new(auth_headers)
        end

        def compensation_service
          EVSS::DisabilityCompensationForm::Service.new(auth_headers)
        end

        def auth_headers
          EVSS::DisabilityCompensationAuthHeaders.new(@user).add_headers(EVSS::AuthHeaders.new(@user).to_h)
        end
      end
    end
  end
end
