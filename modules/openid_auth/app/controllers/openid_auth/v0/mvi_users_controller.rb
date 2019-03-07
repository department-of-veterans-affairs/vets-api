# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'

module OpenidAuth
  module V0
    class MviUsersController < ApplicationController
      skip_before_action :authenticate
      before_action :check_required_headers

      # Allows MVI lookups based on user identity traits (presumably obtained from the upstream
      # identity provider). Returns a 200 response when the MVI lookup succeeds. Raises an error
      # otherwise.
      def show
        user_identity = save_requested_identity
        service = MVI::Service.new
        mvi_response = service.find_profile(user_identity)
        raise mvi_response.error if mvi_response.error

        render json: mvi_response, serializer: MviLookupSerializer
      end

      private

      def check_required_headers
        raise Common::Exceptions::ParameterMissing, 'x-va-level-of-assurance' if missing_loa
      end

      def missing_loa
        request.headers['x-va-level-of-assurance'].blank?
      end

      def save_requested_identity
        # In addition to constructing the the identity object, we save it in order to prime the
        # identity cache. This is done because this endpoint is primarily called by the saml-proxy
        # during the login process. If a user is logging in, usually a client app will make use of
        # the openid token soon.
        OpenidUserIdentity.new(
          uuid: request.headers['x-va-idp-uuid'],
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
          }
        )
      end
    end
  end
end
