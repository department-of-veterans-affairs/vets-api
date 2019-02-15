# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'

module OpenidAuth
  module V0
    class MviUsersController < ApplicationController
      skip_before_action :authenticate
      before_action :check_required_headers

      def show
        user = build_user(build_identity)
        service = MVI::Service.new
        @mvi_response = service.find_profile(user)
        raise @mvi_response.error if @mvi_response.error
        icn_found
      end

      private

      def build_user(user_identity)
        User.new(user_identity.attributes)
      end

      def icn_found
        render json:
          {
            "id": @mvi_response.profile.icn,
            "type": 'user-mvi-icn',
            "data": {
              "attributes": {
                "icn": @mvi_response.profile.icn,
                "first_name": @mvi_response.profile&.given_names&.first,
                "last_name": @mvi_response.profile&.family_name
              }
            }
          }
      end

      def check_required_headers
        raise Common::Exceptions::ParameterMissing, 'x-va-level-of-assurance' if missing_loa
      end

      def missing_loa
        request.headers['x-va-level-of-assurance'].blank?
      end

      def build_identity
        UserIdentity.create(uuid: request.headers['x-va-idp-uuid'],
                            email: request.headers['x-va-user-email'],
                            first_name: request.headers['x-va-first-name'],
                            last_name: request.headers['x-va-last-name'],
                            # TODO: break this out into a method that handles unknown gender
                            gender: request.headers['x-va-gender']&.chars&.first&.upcase,
                            birth_date: request.headers['x-va-dob'],
                            ssn: request.headers['x-va-ssn'],
                            mhv_icn: request.headers['x-va-mhv-icn'],
                            dslogon_edipi: request.headers['x-va-dslogon-edipi'],
                            loa:
                            {
                              current: request.headers['x-va-level-of-assurance'].to_i,
                              highest: request.headers['x-va-level-of-assurance'].to_i
                            })
      end
    end
  end
end
