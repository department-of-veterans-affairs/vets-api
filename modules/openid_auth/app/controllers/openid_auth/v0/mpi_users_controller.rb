# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'
require 'mvi/service'
require 'common/exceptions'

module OpenidAuth
  module V0
    class MPIUsersController < ApplicationController
      skip_before_action :authenticate
      before_action :check_required_headers, only: :show

      def search
        user_attributes = params
        check_level_of_assurance user_attributes
        user_identity = build_identity_from_attributes(user_attributes)
        process_identity(user_identity)
      end

      # DEPRECATED. GET method that parses user identity from header values. Because
      # HTTP headers do not handle UTF-8 values (they are encoded as Latin-1 strings),
      # the POST search action using JSON is preferred.
      def show
        user_identity = build_identity_from_headers
        process_identity(user_identity)
      end

      private

      def process_identity(user_identity)
        service = MVI::Service.new
        mvi_response = service.find_profile(user_identity)
        raise mvi_response.error if mvi_response.error

        render json: mvi_response, serializer: MPILookupSerializer
      end

      def check_required_headers
        raise Common::Exceptions::ParameterMissing, 'x-va-level-of-assurance' if missing_loa
      end

      def missing_loa
        request.headers['x-va-level-of-assurance'].blank?
      end

      def check_level_of_assurance(user_attributes)
        has_loa = !user_attributes[:level_of_assurance].nil?
        raise Common::Exceptions::ParameterMissing, 'level_of_assurance' unless has_loa
      end

      def build_identity_from_attributes(user_attributes)
        OpenidUserIdentity.new(
          uuid: user_attributes[:idp_uuid],
          email: user_attributes[:user_email],
          first_name: user_attributes[:first_name],
          last_name: user_attributes[:last_name],
          gender: user_attributes[:gender]&.chars&.first&.upcase,
          birth_date: user_attributes[:dob],
          ssn: user_attributes[:ssn],
          mhv_icn: user_attributes[:mhv_icn],
          dslogon_edipi: user_attributes[:dslogon_edipi],
          loa:
          {
            current: user_attributes[:level_of_assurance].to_i,
            highest: user_attributes[:level_of_assurance].to_i
          }
        )
      end

      def build_identity_from_headers
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
