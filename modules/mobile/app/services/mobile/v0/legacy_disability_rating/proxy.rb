# frozen_string_literal: true

require 'common/exceptions'

module Mobile
  module V0
    module LegacyDisabilityRating
      class Proxy
        def initialize(user)
          @user = user
        end

        def get_disability_ratings
          combine_response, individual_response = Parallel.map([get_combine_rating, get_individual_ratings],
                                                               in_threads: 2, &:call)
          Mobile::V0::Adapters::LegacyRating.new.disability_ratings(combine_response, individual_response)
        rescue => e
          if !e.respond_to?('response') && !e.respond_to?('status_code')
            Rails.logger.info('LEGACY DR ERRORS', error: e)
            raise e
          end

          status_code = e.respond_to?('response') ? e.response[:status] : e.status_code
          case status_code
          when 400
            raise Common::Exceptions::BackendServiceException, 'MOBL_404_rating_not_found'
          when 502
            raise Common::Exceptions::BackendServiceException, 'MOBL_502_upstream_error'
          when 403
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

        def get_combine_rating
          lambda {
            common_service.get_rating_info
          }
        end

        def get_individual_ratings
          lambda {
            compensation_service.get_rated_disabilities
          }
        end
      end
    end
  end
end
