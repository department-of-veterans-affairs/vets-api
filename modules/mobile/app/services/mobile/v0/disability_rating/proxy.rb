# frozen_string_literal: true

require 'common/exceptions'

module Mobile
  module V0
    module DisabilityRating
      class Proxy
        def initialize(user)
          @user = user
        end

        # rubocop:disable Metrics/MethodLength
        def get_disability_ratings
          combine_response, individual_response = Parallel.map([get_combine_rating, get_individual_ratings],
                                                               in_threads: 2, &:call)
          Mobile::V0::Adapters::Rating.new.disability_ratings(combine_response, individual_response)
        rescue => e
          status_code, details = if e.respond_to?('response')
                                   [e.response[:status], e.response]
                                 else
                                   [e.status_code, e.errors]
                                 end
          Rails.logger.info('Mobile Disability Rating Error Details: ', details:)
          Rails.logger.info('Mobile Disability Rating Expanded Error: ',
                            "response value: #{e.response_values if defined? e.response_values}.
                            original status: #{e.original_status if defined? e.original_status}.
                            original body: #{e.original_body if defined? e.original_body}.
                            key: #{e.key if defined? e.key}.")
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
        # rubocop:enable Metrics/MethodLength

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
