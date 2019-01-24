# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'

module OpenidAuth
  module V0
    class MviUsersController < ApplicationController
      skip_before_action :authenticate

      def show
        if request.headers['x-va-ssn'].present?
          build_ssn_user
        else
          build_edipi_user
        end
        @user = User.new @user_identity
        Mvi.for_user(@user)

        if @user.icn.present?
          icn_found
        else
          icn_not_found
        end
      end

      private

      def build_edipi_user
        @user_identity = UserIdentity.create(uuid: request.headers['x-va-edipi'],
                                             email: request.headers['x-va-user-email'],
                                             ssn: request.headers['x-va-edipi'],
                                             loa:
                                             {
                                               current: request.headers['x-va-current-level-of-assurance'].to_i,
                                               highest: request.headers['x-va-highest-level-of-assurance'].to_i
                                             })
      end

      def build_ssn_user
        @user_identity = UserIdentity.create(uuid: request.headers['x-va-ssn'],
                                             email: request.headers['x-va-user-email'],
                                             first_name: request.headers['x-va-first-name'],
                                             last_name: request.headers['x-va-last-name'],
                                             birth_date: request.headers['x-va-dob'],
                                             ssn: request.headers['x-va-ssn'],
                                             loa:
                                             {
                                               current: request.headers['x-va-current-level-of-assurance'].to_i,
                                               highest: request.headers['x-va-highest-level-of-assurance'].to_i
                                             })
      end

      def icn_found
        render json:
          {
            "id": @user.icn,
            "type": 'user-mvi-icn',
            "data": {
              "attributes": {
                "icn": @user.icn
              }
            }
          }
      end

      def icn_not_found
        render json:
          {
            "id": 'not_found',
            "type": 'user-mvi-icn',
            "data": {
              "errors": {
                "icn": 'could not locate ICN'
              }
            }
          }
      end

      def validated_payload
        @validated_payload ||= OpenStruct.new(token_payload.merge(va_identifiers: { icn: @current_user.icn }))
      end
    end
  end
end
