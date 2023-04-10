# frozen_string_literal: true

# Income limits api response data shape example:
# {
#   "county_name": "Some County, XX",
#   "income_year": 2022,
#   "limits": {
#     "national_threshold": {
#       "0_depedent": 99999,
#       "1_dependent": 99999,
#       "additional_dependents": 9999
#     },
#     "relaxation_threshold": {
#       "0_dependent": 99999,
#       "1_dependent": 99999,
#       "additional_dependents": 9999
#     },
#     "housebound_threshold": {
#       "0_dependent": 99999,
#       "1_dependent": 99999,
#       "additional_dependents": 9999
#     },
#     "aid_attendence_threshold": {
#       "0_dependent": 99999,
#       "1_dependent": 99999,
#       "additional_dependents": 9999
#     },
#     "pension_threshold": {
#       "0_dependent": 99999,
#       "1_dependent": 99999,
#       "additional_dependents": 9999
#     },
#     "gmt_threshold": 9999
#   }
# }

module IncomeLimits
  module V1
    class IncomeLimitsController < ApplicationController
      skip_before_action :authenticate

      def index
        example_data = {
          county_name: 'Some County, XX',
          income_year: 2022,
          limits: {
            national_threshold: { '0_depedent': 99_999, '1_dependent': 99_999, additional_dependents: 9999 },
            relaxation_threshold: { '0_dependent': 99_999, '1_dependent': 99_999, additional_dependents: 9999 },
            housebound_threshold: { '0_dependent': 99_999, '1_dependent': 99_999, additional_dependents: 9999 },
            aid_attendence_threshold: { '0_dependent': 99_999, '1_dependent': 99_999, additional_dependents: 9999 },
            pension_threshold: { '0_dependent': 99_999, '1_dependent': 99_999, additional_dependents: 9999 },
            gmt_threshold: 9999
          }
        }
        unless validate_income_limits_params
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Invalid paramaters')
        end

        render json: { message: example_data }
      end

      private

      def validate_income_limits_params
        return true unless params.key?(:filter)

        %w[zip year dependents].include?(params[:filter])
      end

      def find_limit_by_params
        @limits = IncomeLimits::LimitsByZipCode.find_by id: params[:zip, :year, :dependents]
        raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Resource not found') unless @limits
      end
    end
  end
end
